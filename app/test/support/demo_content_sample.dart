import 'package:appi/demo_content.dart';

const sampleContent = DemoContent(
  kiosk: DemoKiosk(title: 'Schulkiosk', description: 'Ein Beitrag für euren Ball.',
    opening: 'Mo–Do · große Pause', location: 'Mensa', finance: DemoFinance(86000, 26000, 60000),
    products: [DemoProduct('Kaffee', 'Frisch aufgebrüht', 150), DemoProduct('Brezel', 'Für die Pause', 120)],
    notes: [DemoNote('Die nächste Schicht', 'Alex & Jamie übernehmen die große Pause.')]),
  actions: [DemoAction(id: 'schulfest', title: 'Schulfest', description: 'Kuchen und Limo für den Jahrgang.',
    dateLabel: 'Beispiel: 12. Juni', location: 'Schulhof', artwork: 'festival',
    chips: ['Kuchen & Getränke'], idea: 'Wer hilft beim Aufbau?', finance: DemoFinance(72000, 18000, 54000))],
  contacts: [DemoContact('Alex Beispiel', 'Kiosk & Verkaufsstände')],
);
