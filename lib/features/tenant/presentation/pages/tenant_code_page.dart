import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../application/tenant_controller.dart';

class TenantCodePage extends ConsumerStatefulWidget {
  const TenantCodePage({super.key});

  @override
  ConsumerState<TenantCodePage> createState() => _TenantCodePageState();
}

class _TenantCodePageState extends ConsumerState<TenantCodePage> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(tenantControllerProvider.notifier)
        .submitCode(_codeCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final tenant = ref.watch(tenantControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.storefront, size: 64),
                    const Gap(12),
                    Text(
                      'Mendez POS',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const Gap(4),
                    Text(
                      'Ingresa el código de tu sucursal para continuar',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const Gap(32),
                    TextFormField(
                      controller: _codeCtrl,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      autocorrect: false,
                      autofillHints: const [AutofillHints.organizationName],
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        TextInputFormatter.withFunction(
                          (_, next) =>
                              next.copyWith(text: next.text.toLowerCase()),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Código de sucursal',
                        prefixIcon: Icon(Icons.qr_code),
                        hintText: 'mendez',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El código es obligatorio';
                        }
                        return null;
                      },
                    ),
                    if (tenant.errorMessage != null) ...[
                      const Gap(16),
                      _ErrorBanner(message: tenant.errorMessage!),
                    ],
                    const Gap(24),
                    FilledButton(
                      onPressed: tenant.isSubmitting ? null : _submit,
                      child: tenant.isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Continuar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade900),
            ),
          ),
        ],
      ),
    );
  }
}
