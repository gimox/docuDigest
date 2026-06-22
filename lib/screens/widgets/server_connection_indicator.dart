import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/ocr_state.dart';

class ServerConnectionIndicator extends ConsumerWidget {
  const ServerConnectionIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStatus = ref.watch(ocrConnectionStatusProvider);
    final settings = ref.watch(ocrSettingsNotifierProvider);
    final serverName = settings.apiMode == 'ollama' ? 'Ollama' : 'MLX Apple';

    return connectionStatus.when(
      data: (isConnected) {
        final color = isConnected ? Colors.greenAccent : Colors.redAccent;
        final tooltip = isConnected 
            ? 'Connesso a $serverName (${settings.apiHost}:${settings.apiPort})'
            : 'Non connesso a $serverName (${settings.apiHost}:${settings.apiPort})';
        return Tooltip(
          message: tooltip,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: isConnected ? [
                BoxShadow(
                  color: Colors.greenAccent.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                )
              ] : null,
            ),
          ),
        );
      },
      loading: () => const Tooltip(
        message: 'Verifica connessione...',
        child: SizedBox(
          width: 8,
          height: 8,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Colors.amberAccent,
          ),
        ),
      ),
      error: (_, __) => Tooltip(
        message: 'Errore di connessione',
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.redAccent,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
