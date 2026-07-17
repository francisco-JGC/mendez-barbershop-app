import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../application/printer_settings_controller.dart';
import '../../domain/entities/thermal_printer_device.dart';

class PrinterSettingsPage extends ConsumerWidget {
  const PrinterSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(printerSettingsControllerProvider);
    final controller = ref.read(printerSettingsControllerProvider.notifier);

    ref.listen(printerSettingsControllerProvider, (prev, next) {
      final messenger = ScaffoldMessenger.of(context);
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        messenger.showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
      if (next.infoMessage != null && next.infoMessage != prev?.infoMessage) {
        messenger.showSnackBar(SnackBar(content: Text(next.infoMessage!)));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Impresora térmica')),
      body: RefreshIndicator(
        onRefresh: controller.scan,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionTitle('Estado'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(
                        state.isConnected
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth_disabled,
                        color: state.isConnected ? Colors.green : Colors.grey,
                      ),
                      const Gap(8),
                      Text(state.isConnected ? 'Conectada' : 'Desconectada',
                          style: Theme.of(context).textTheme.titleMedium),
                    ]),
                    if (state.selected != null) ...[
                      const Gap(8),
                      Text('Impresora: ${state.selected!.name}'),
                      Text('MAC: ${state.selected!.macAddress}'),
                      const Gap(12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (state.isConnected)
                            OutlinedButton.icon(
                              icon: const Icon(Icons.bluetooth_disabled),
                              label: const Text('Desconectar'),
                              onPressed: controller.disconnect,
                            ),
                          if (!state.isConnected)
                            OutlinedButton.icon(
                              icon: const Icon(Icons.bluetooth_searching),
                              label: const Text('Conectar'),
                              onPressed: () =>
                                  controller.selectDevice(state.selected!),
                            ),
                          TextButton.icon(
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Olvidar impresora'),
                            onPressed: controller.forgetPrinter,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Gap(16),
            _SectionTitle('Ancho de papel'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SegmentedButton<PaperWidth>(
                  segments: PaperWidth.values
                      .map((w) => ButtonSegment(
                            value: w,
                            label: Text('${w.mm} mm'),
                          ))
                      .toList(),
                  selected: {state.paperWidth},
                  onSelectionChanged: (s) =>
                      controller.changePaperWidth(s.first),
                ),
              ),
            ),
            const Gap(16),
            _SectionTitle('Auto-impresión'),
            Card(
              child: SwitchListTile(
                value: state.autoPrint,
                onChanged: controller.toggleAutoPrint,
                title: const Text('Imprimir ticket automáticamente'),
                subtitle: const Text(
                    'Al registrar una venta se envía el ticket a la impresora sin preguntar'),
              ),
            ),
            const Gap(16),
            Row(children: [
              _SectionTitle('Dispositivos emparejados'),
              const Spacer(),
              TextButton.icon(
                onPressed: state.isScanning ? null : controller.scan,
                icon: state.isScanning
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                label: const Text('Buscar'),
              ),
            ]),
            if (state.devices.isEmpty && !state.isScanning)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Empareja la impresora desde los ajustes de Bluetooth del dispositivo, luego toca Buscar.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ...state.devices.map((d) => _DeviceTile(
                  device: d,
                  isSelected: d == state.selected,
                  isConnecting: state.isConnecting,
                  onSelect: () => controller.selectDevice(d),
                )),
            const Gap(24),
            FilledButton.icon(
              onPressed: (state.selected == null || state.isTesting)
                  ? null
                  : () => controller.printTest(ref),
              icon: state.isTesting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.print),
              label: const Text('Imprimir ticket de prueba'),
            ),
            const Gap(8),
            OutlinedButton.icon(
              onPressed: (state.selected == null || state.isTesting)
                  ? null
                  : controller.printMinimalTest,
              icon: const Icon(Icons.bug_report_outlined),
              label: const Text('Test mínimo (diagnóstico)'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: Colors.grey.shade700),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.isSelected,
    required this.isConnecting,
    required this.onSelect,
  });

  final ThermalPrinterDevice device;
  final bool isSelected;
  final bool isConnecting;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(device.name),
        subtitle: Text(device.macAddress),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: isConnecting ? null : onSelect,
      ),
    );
  }
}
