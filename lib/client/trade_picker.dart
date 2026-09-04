import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'catalog_query.dart';

Future<ServiceCategory?> showTradePicker(
  BuildContext context, {
  required List<ServiceCategory> catalog,
  ServiceCategory? selected,
}) {
  return Navigator.of(context).push<ServiceCategory>(
    MaterialPageRoute(
      builder: (_) => _TradePickerPage(catalog: catalog, selected: selected),
    ),
  );
}

class _TradePickerPage extends StatefulWidget {
  const _TradePickerPage({required this.catalog, this.selected});

  final List<ServiceCategory> catalog;
  final ServiceCategory? selected;

  @override
  State<_TradePickerPage> createState() => _TradePickerPageState();
}

class _TradePickerPageState extends State<_TradePickerPage> {
  final query = TextEditingController();

  @override
  void initState() {
    super.initState();
    query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = filterCategories(widget.catalog, query.text);
    return Scaffold(
      backgroundColor: NeeColors.paper,
      appBar: AppBar(title: const Text('Elegir oficio')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              controller: query,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Buscar plomería, belleza, tech…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text(
                      'No hay un oficio con ese nombre.\nSigue escribiendo o elige otro.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: NeeColors.muted, height: 1.4),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final category = items[index];
                      final on = widget.selected?.id == category.id;
                      return ListTile(
                        leading: Icon(category.icon, color: NeeColors.soot),
                        title: Text(category.name),
                        trailing: on
                            ? const Icon(Icons.check, color: NeeColors.open)
                            : null,
                        onTap: () => Navigator.pop(context, category),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
