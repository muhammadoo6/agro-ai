import 'json_utils.dart';

enum TransactionType { income, expense }

enum TransactionCategory {
  seeds,
  fertilizer,
  pesticide,
  water,
  fuel,
  labor,
  equipment,
  rent,
  sale,
  subsidy,
  other;

  static const expenseCategories = [
    seeds,
    fertilizer,
    pesticide,
    water,
    fuel,
    labor,
    equipment,
    rent,
    other,
  ];
  static const incomeCategories = [sale, subsidy, other];
}

/// Хароҷот ё даромад.
class FarmTransaction {
  const FarmTransaction({
    required this.id,
    required this.type,
    required this.category,
    required this.amount,
    required this.date,
    this.plotId,
    this.harvestId,
    this.note,
  });

  final String id;
  final TransactionType type;
  final TransactionCategory category;
  final double amount;
  final DateTime date;
  final String? plotId;

  /// Агар даромад аз сабти ҳосил сохта шуда бошад.
  final String? harvestId;
  final String? note;

  /// Маблағ бо аломат: даромад +, хароҷот −.
  double get signedAmount => type == TransactionType.income ? amount : -amount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'category': category.name,
        'amount': amount,
        'date': date.toIso8601String(),
        'plotId': plotId,
        'harvestId': harvestId,
        'note': note,
      };

  factory FarmTransaction.fromJson(Map<String, dynamic> j) => FarmTransaction(
        id: j['id'] as String,
        type: enumFromName(
            TransactionType.values, j['type'], TransactionType.expense),
        category: enumFromName(
            TransactionCategory.values, j['category'], TransactionCategory.other),
        amount: toDouble(j['amount']),
        date: dateFromJson(j['date']) ?? DateTime.now(),
        plotId: j['plotId'] as String?,
        harvestId: j['harvestId'] as String?,
        note: j['note'] as String?,
      );
}
