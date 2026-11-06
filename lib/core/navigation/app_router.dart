import 'package:flutter/material.dart';

import '../../features/farm_diary/harvest_form_screen.dart';
import '../../features/farm_diary/transaction_form_screen.dart';
import '../../features/irrigation/irrigation_form_screen.dart';
import '../../features/irrigation/irrigation_screen.dart';
import '../../features/knowledge/crop_guide.dart';
import '../../features/knowledge/crop_guide_screen.dart';
import '../../features/plant_scan/scan_result_screen.dart';
import '../../features/plots/crop_cycle_form_screen.dart';
import '../../features/plots/plot_detail_screen.dart';
import '../../features/plots/plot_form_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../models/crop_cycle.dart';
import '../../models/harvest.dart';
import '../../models/irrigation.dart';
import '../../models/plant_scan.dart';
import '../../models/plot.dart';
import '../../models/transaction.dart';

/// Гузариш байни саҳифаҳо. Ҳамаи роҳҳо дар як ҷо.
class AppRouter {
  static Future<T?> _push<T>(BuildContext context, Widget page) =>
      Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

  static Future<void> settings(BuildContext c) => _push(c, const SettingsScreen());

  static Future<void> plotForm(BuildContext c, {Plot? plot}) =>
      _push(c, PlotFormScreen(plot: plot));

  static Future<void> plotDetail(BuildContext c, String plotId) =>
      _push(c, PlotDetailScreen(plotId: plotId));

  static Future<void> cycleForm(BuildContext c,
          {required String plotId, CropCycle? cycle}) =>
      _push(c, CropCycleFormScreen(plotId: plotId, cycle: cycle));

  static Future<void> irrigation(BuildContext c) =>
      _push(c, const IrrigationScreen());

  static Future<void> irrigationForm(BuildContext c,
          {String? plotId, Irrigation? irrigation}) =>
      _push(c, IrrigationFormScreen(plotId: plotId, irrigation: irrigation));

  static Future<void> transactionForm(BuildContext c,
          {FarmTransaction? transaction,
          TransactionType type = TransactionType.expense,
          String? plotId}) =>
      _push(
          c,
          TransactionFormScreen(
              transaction: transaction, initialType: type, plotId: plotId));

  static Future<void> harvestForm(BuildContext c,
          {Harvest? harvest, String? plotId}) =>
      _push(c, HarvestFormScreen(harvest: harvest, plotId: plotId));

  static Future<void> scanResult(BuildContext c, PlantScan scan) =>
      _push(c, ScanResultScreen(scanId: scan.id, initial: scan));

  static Future<void> cropGuide(BuildContext c, CropGuide guide) =>
      _push(c, CropGuideScreen(guide: guide));
}
