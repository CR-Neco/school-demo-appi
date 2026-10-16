"""Local PDF generation. No external service, payment initiation or access tokens."""
from datetime import datetime
from io import BytesIO
from pathlib import Path
from urllib.parse import quote
from xml.sax.saxutils import escape
from zoneinfo import ZoneInfo

import reportlab
from reportlab.graphics.barcode.qr import QrCodeWidget
from reportlab.graphics.shapes import Drawing
from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

DEMO_RECIPIENT = 'AppI Demo-Abikasse (fiktiv)'
DEMO_IBAN = 'DE00 0000 0000 0000 0000 00'
INK = colors.HexColor('#172D37')
MINT = colors.HexColor('#DDF49C')
MUTED = colors.HexColor('#617079')

# Vera ships with ReportLab; no OS font installation or runtime download required.
_font_dir = Path(reportlab.__file__).resolve().parent / 'fonts'
pdfmetrics.registerFont(TTFont('AppiRegular', str(_font_dir / 'Vera.ttf')))
pdfmetrics.registerFont(TTFont('AppiBold', str(_font_dir / 'VeraBd.ttf')))
pdfmetrics.registerFontFamily('AppiRegular', normal='AppiRegular', bold='AppiBold')


def qr_target(reference: str) -> str:
    """An explicitly non-functional demo link, not an authenticated buyer URL."""
    return 'appi-demo://reservation/' + quote(reference, safe='')


def euro(cents: int) -> str:
    whole, fraction = divmod(cents, 100)
    return f'{whole:,}'.replace(',', '.') + f',{fraction:02d} €'


def local_time(value: str) -> str:
    date = datetime.fromisoformat(value).astimezone(ZoneInfo('Europe/Berlin'))
    return date.strftime('%d.%m.%Y, %H:%M Uhr') + ' (Europe/Berlin)'


def render_receipt(reservation: dict, event: dict, school: str) -> bytes:
    """Only server-owned rows are accepted by the endpoint; no PDF fields from clients."""
    output = BytesIO()
    width = A4[0] - 84
    base = ParagraphStyle('body', fontName='AppiRegular', fontSize=10,
                          leading=15, textColor=INK, alignment=TA_LEFT,
                          splitLongWords=True)
    small = ParagraphStyle('small', parent=base, fontSize=8, leading=12, textColor=MUTED)
    heading = ParagraphStyle('heading', parent=base, fontName='AppiBold', fontSize=23, leading=28)
    bold = ParagraphStyle('bold', parent=base, fontName='AppiBold')
    label = ParagraphStyle('label', parent=base, fontSize=9, textColor=MUTED)
    white = ParagraphStyle('white', parent=base, fontName='AppiBold', fontSize=20,
                           leading=25, textColor=colors.white)

    def p(text, style=base):
        return Paragraph(escape(str(text)).replace('\n', '<br/>'), style)

    doc = SimpleDocTemplate(output, pagesize=A4, rightMargin=42, leftMargin=42,
                            topMargin=36, bottomMargin=42, title='PMG AppI - Reservierungsbeleg (Demo)',
                            author='PMG AppI Demo', pageCompression=1)
    banner = Table([[p('PMG AppI', white), p('LOKALE DEMO', ParagraphStyle(
        'mint', parent=small, textColor=MINT, fontName='AppiBold'))]], colWidths=[width-120, 120])
    banner.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), INK),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('LEFTPADDING', (0, 0), (-1, -1), 16), ('TOPPADDING', (0, 0), (-1, -1), 12),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 12),
    ]))
    status = {'reserved': 'Reserviert - noch nicht bezahlt', 'paid': 'Bezahlt', 'cancelled': 'Storniert'}[reservation['status']]
    if reservation.get('overdue'):
        status += ' - Zahlungsfrist überschritten'
    rows = [
        ('Name', reservation['name']),
        ('Reservierungsnummer', reservation['id']),
        ('Status', status),
        ('Kartenanzahl', str(reservation['quantity'])),
        ('Preis pro Karte', euro(reservation['price_cents'])),
        ('Gesamtbetrag', euro(reservation['total_cents'])),
        ('Reserviert am', local_time(reservation['created_at'])),
        ('Zahlungsfrist', local_time(reservation['expires_at'])),
    ]
    details = Table([[p(key, label), p(value, bold if key == 'Gesamtbetrag' else base)]
                     for key, value in rows], colWidths=[132, width-132])
    details.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('LEFTPADDING', (0, 0), (-1, -1), 10), ('RIGHTPADDING', (0, 0), (-1, -1), 10),
        ('TOPPADDING', (0, 0), (-1, -1), 6), ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('BACKGROUND', (0, 5), (-1, 5), MINT),
        ('LINEBELOW', (0, -1), (-1, -1), 0.5, colors.HexColor('#DCE2DF')),
    ]))
    if reservation['status'] == 'paid':
        payment_note = 'Zahlung im Demo-Backend bestätigt. Keine weitere Zahlung erforderlich.'
    elif reservation['status'] == 'cancelled':
        payment_note = 'Diese Reservierung ist storniert. Bitte keine Zahlung veranlassen.'
    else:
        payment_note = 'In einem echten Ablauf: Gesamtbetrag bis zur Frist mit dieser Referenz überweisen.'
    payment = Table([[p('Zahlungsinformationen - ausschließlich Demo', bold)],
        [p('Empfänger: ' + DEMO_RECIPIENT)], [p('Demo-IBAN: ' + DEMO_IBAN)],
        [p('Verwendungszweck: ' + reservation['id'])], [p(payment_note)],
        [p('Nicht überweisen! Die IBAN ist absichtlich ungültig. Es werden keine echten Kontodaten verwendet.', bold)]],
        colWidths=[width])
    payment.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor('#F1F3EB')),
        ('LEFTPADDING', (0, 0), (-1, -1), 12), ('RIGHTPADDING', (0, 0), (-1, -1), 12),
        ('TOPPADDING', (0, 0), (-1, -1), 4), ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
    ]))
    target = qr_target(reservation['id'])
    qr = Drawing(104, 104)
    qr.add(QrCodeWidget(value=target, barWidth=104, barHeight=104, barBorder=4, barLevel='M'))
    qr_info = Table([[qr, p('QR zur Reservierungsreferenz\n' + target +
        '\nDemo-Link ohne hinterlegte App-/Website-Route. Er kann in dieser Demo nicht geöffnet werden. '
        'Der QR bestätigt weder Zahlung noch Eintritt und enthält keinen Org-Zugang.', small)]],
        colWidths=[120, width-120])
    qr_info.setStyle(TableStyle([('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('LEFTPADDING', (0, 0), (-1, -1), 0), ('RIGHTPADDING', (0, 0), (-1, -1), 8)]))
    story = [banner, Spacer(1, 18), p('Reservierungsbeleg', heading), Spacer(1, 5),
        p('DEMO - noch keine Eintrittskarte', bold), Spacer(1, 12),
        p(event['title'], bold), p(school, small), Spacer(1, 12), details,
        Spacer(1, 16), payment, Spacer(1, 14), qr_info]

    def footer(canvas, document):
        canvas.saveState()
        canvas.setFont('AppiRegular', 8)
        canvas.setFillColor(MUTED)
        canvas.drawString(42, 23, 'PMG AppI | Reservierungsbeleg | Fiktive Demo-Daten')
        canvas.drawRightString(A4[0]-42, 23, f'Seite {document.page}')
        canvas.restoreState()

    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    return output.getvalue()
