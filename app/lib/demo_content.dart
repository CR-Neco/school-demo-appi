abstract interface class DemoContentApi {
  Future<DemoContent> loadDemoContent();
}

Map<String, dynamic> _map(dynamic value) {
  if (value is! Map<String, dynamic>) throw const FormatException('Objekt fehlt');
  return value;
}
String _text(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) throw const FormatException('Text fehlt');
  return value;
}
int _number(Map<String, dynamic> json, String key, {bool signed = false}) {
  final value = json[key];
  if (value is! int || (!signed && value < 0)) throw const FormatException('Betrag ungültig');
  return value;
}
List<T> _items<T>(dynamic value, T Function(Map<String, dynamic>) parse) {
  if (value is! List) throw const FormatException('Liste fehlt');
  return value.map((item) => parse(_map(item))).toList();
}

class DemoProduct {
  const DemoProduct(this.name, this.description, this.priceCents);
  factory DemoProduct.fromJson(Map<String, dynamic> json) => DemoProduct(
    _text(json, 'name'), _text(json, 'description'), _number(json, 'price_cents'));
  final String name, description;
  final int priceCents;
}

class DemoNote {
  const DemoNote(this.title, this.body);
  factory DemoNote.fromJson(Map<String, dynamic> json) => DemoNote(_text(json, 'title'), _text(json, 'body'));
  final String title, body;
}

class DemoContact {
  const DemoContact(this.name, this.role);
  factory DemoContact.fromJson(Map<String, dynamic> json) => DemoContact(_text(json, 'name'), _text(json, 'role'));
  final String name, role;
}

class DemoFinance {
  const DemoFinance(this.incomeCents, this.expensesCents, this.raisedCents);
  factory DemoFinance.fromJson(Map<String, dynamic> json) {
    final income = _number(json, 'income_cents');
    final expenses = _number(json, 'expenses_cents');
    final raised = _number(json, 'raised_cents', signed: true);
    if (raised != income - expenses) throw const FormatException('Finanzsummen widersprüchlich');
    return DemoFinance(income, expenses, raised);
  }
  final int incomeCents, expensesCents, raisedCents;
}

class DemoAction {
  const DemoAction({required this.id, required this.title, required this.description,
    required this.dateLabel, required this.location, required this.artwork,
    required this.chips, required this.idea, required this.finance});
  factory DemoAction.fromJson(Map<String, dynamic> json) {
    final chips = json['chips'];
    if (chips is! List || chips.any((item) => item is! String)) throw const FormatException('Chips fehlen');
    return DemoAction(id: _text(json, 'id'), title: _text(json, 'title'), description: _text(json, 'description'),
      dateLabel: _text(json, 'date_label'), location: _text(json, 'location'), artwork: _text(json, 'artwork'),
      chips: chips.cast<String>(), idea: _text(json, 'idea'), finance: DemoFinance.fromJson(json));
  }
  final String id, title, description, dateLabel, location, artwork, idea;
  final List<String> chips;
  final DemoFinance finance;
}

class DemoKiosk {
  const DemoKiosk({required this.title, required this.description, required this.opening,
    required this.location, required this.products, required this.notes, required this.finance});
  factory DemoKiosk.fromJson(Map<String, dynamic> json) => DemoKiosk(
    title: _text(json, 'title'), description: _text(json, 'description'), opening: _text(json, 'opening'),
    location: _text(json, 'location'), products: _items(json['products'], DemoProduct.fromJson),
    notes: _items(json['notes'], DemoNote.fromJson), finance: DemoFinance.fromJson(json));
  final String title, description, opening, location;
  final List<DemoProduct> products;
  final List<DemoNote> notes;
  final DemoFinance finance;
}

class DemoContent {
  const DemoContent({required this.kiosk, required this.actions, required this.contacts});
  factory DemoContent.fromJson(Map<String, dynamic> json) {
    if (json['is_demo'] != true) throw const FormatException('Demo-Kennzeichnung fehlt');
    return DemoContent(kiosk: DemoKiosk.fromJson(_map(json['kiosk'])),
      actions: _items(json['actions'], DemoAction.fromJson), contacts: _items(json['contacts'], DemoContact.fromJson));
  }
  final DemoKiosk kiosk;
  final List<DemoAction> actions;
  final List<DemoContact> contacts;
}
