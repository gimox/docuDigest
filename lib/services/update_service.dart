import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String currentAppVersion = '1.0.6';

bool _isNewerVersion(String current, String latest) {
  final cleanCurrent = current.replaceAll(RegExp(r'[vV]'), '');
  final cleanLatest = latest.replaceAll(RegExp(r'[vV]'), '');

  final currentParts = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final latestParts = cleanLatest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

  final length = currentParts.length > latestParts.length ? currentParts.length : latestParts.length;
  for (int i = 0; i < length; i++) {
    final currentVal = i < currentParts.length ? currentParts[i] : 0;
    final latestVal = i < latestParts.length ? latestParts[i] : 0;
    if (latestVal > currentVal) return true;
    if (currentVal > latestVal) return false;
  }
  return false;
}

Future<void> _openUrl(String url) async {
  if (Platform.isMacOS) {
    await Process.run('open', [url]);
  } else if (Platform.isWindows) {
    await Process.run('explorer.exe', [url]);
  } else if (Platform.isLinux) {
    await Process.run('xdg-open', [url]);
  }
}

class _DownloadProgressDialog extends StatefulWidget {
  final String url;
  final String savePath;

  const _DownloadProgressDialog({
    required this.url,
    required this.savePath,
  });

  @override
  State<_DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double _progress = 0.0;
  String _status = 'Inizializzazione download...';
  bool _completed = false;
  String? _error;
  http.Client? _client;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      _client = http.Client();
      final request = http.Request('GET', Uri.parse(widget.url));
      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        throw Exception('Errore server: ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final file = File(widget.savePath);
      final sink = file.openWrite();

      int bytesReceived = 0;
      await response.stream.listen(
        (chunk) {
          sink.add(chunk);
          bytesReceived += chunk.length;
          setState(() {
            if (contentLength > 0) {
              _progress = bytesReceived / contentLength;
              _status = 'Scaricamento: ${(bytesReceived / (1024 * 1024)).toStringAsFixed(1)} MB / ${(contentLength / (1024 * 1024)).toStringAsFixed(1)} MB';
            } else {
              _status = 'Scaricamento: ${(bytesReceived / (1024 * 1024)).toStringAsFixed(1)} MB';
            }
          });
        },
        onError: (e) {
          throw e;
        },
        cancelOnError: true,
      ).asFuture();

      await sink.close();
      setState(() {
        _completed = true;
        _status = 'Download completato!';
      });
      
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _status = 'Errore durante il download.';
      });
    } finally {
      _client?.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text('Download Aggiornamento', style: TextStyle(color: Colors.white, fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_status, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Chiudi', style: TextStyle(color: Colors.blueAccent)),
            ),
          ] else ...[
            LinearProgressIndicator(
              value: _completed ? 1.0 : (_progress > 0.0 ? _progress : null),
              backgroundColor: const Color(0xFF0F172A),
              color: Colors.tealAccent,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _client?.close();
                Navigator.of(context).pop(false);
              },
              child: const Text('Annulla', style: TextStyle(color: Colors.white54)),
            ),
          ]
        ],
      ),
    );
  }
}

Future<void> checkForUpdate(BuildContext context, {bool showNoUpdateDialog = false}) async {
  if (kIsWeb) return;

  try {
    final response = await http.get(
      Uri.parse('https://api.github.com/repos/gimox/docuDigest/releases/latest'),
      headers: {'Accept': 'application/vnd.github.v3+json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Impossibile verificare gli aggiornamenti: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final latestVersion = data['tag_name'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    final htmlUrl = data['html_url'] as String? ?? '';
    final assets = data['assets'] as List<dynamic>? ?? [];

    if (_isNewerVersion(currentAppVersion, latestVersion)) {
      if (!context.mounted) return;
      final updateConfirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: Row(
              children: [
                const Icon(Icons.system_update_alt, color: Colors.tealAccent),
                const SizedBox(width: 10),
                Text('Aggiornamento Disponibile ($latestVersion)', style: const TextStyle(color: Colors.white)),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'È disponibile una nuova versione di DocuDigest. Vuoi scaricarla e installarla?',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Note di rilascio:', style: TextStyle(color: Colors.white54, fontSize: 13)),
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 150),
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          body,
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Più tardi', style: TextStyle(color: Colors.white54)),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(backgroundColor: Colors.tealAccent.shade700),
                child: const Text('Aggiorna ora', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );

      if (updateConfirmed == true) {
        String? downloadUrl;
        String? assetName;

        if (Platform.isMacOS) {
          final dmgAsset = assets.firstWhere(
            (a) => (a['name'] as String).toLowerCase().endsWith('.dmg') ||
                   (a['name'] as String).toLowerCase().endsWith('.pkg') ||
                   (a['name'] as String).toLowerCase().contains('mac'),
            orElse: () => null,
          );
          if (dmgAsset != null) {
            downloadUrl = dmgAsset['browser_download_url'] as String?;
            assetName = dmgAsset['name'] as String?;
          }
        } else if (Platform.isWindows) {
          final winAsset = assets.firstWhere(
            (a) => (a['name'] as String).toLowerCase().endsWith('.exe') ||
                   (a['name'] as String).toLowerCase().endsWith('.msix') ||
                   (a['name'] as String).toLowerCase().contains('win'),
            orElse: () => null,
          );
          if (winAsset != null) {
            downloadUrl = winAsset['browser_download_url'] as String?;
            assetName = winAsset['name'] as String?;
          }
        }

        if (downloadUrl == null && assets.isNotEmpty) {
          downloadUrl = assets.first['browser_download_url'] as String?;
          assetName = assets.first['name'] as String?;
        }

        if (downloadUrl != null && assetName != null) {
          final tempDir = Directory.systemTemp;
          final savePath = '${tempDir.path}${Platform.pathSeparator}$assetName';

          if (!context.mounted) return;
          final success = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => _DownloadProgressDialog(url: downloadUrl!, savePath: savePath),
          );

          if (success == true) {
            if (Platform.isMacOS) {
              await Process.run('open', [savePath]);
            } else if (Platform.isWindows) {
              await Process.start(savePath, [], runInShell: true);
              if (context.mounted) {
                await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF1E293B),
                    title: const Text('Installazione in corso', style: TextStyle(color: Colors.white)),
                    content: const Text(
                      'L\'installatore è stato avviato. L\'applicazione verrà ora chiusa per consentire l\'aggiornamento.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      FilledButton(
                        onPressed: () => exit(0),
                        style: FilledButton.styleFrom(backgroundColor: Colors.tealAccent.shade700),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
                exit(0);
              }
            } else {
              await _openUrl(htmlUrl);
            }
          }
        } else {
          await _openUrl(htmlUrl);
        }
      }
    } else {
      if (showNoUpdateDialog) {
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text('Nessun Aggiornamento', style: TextStyle(color: Colors.white)),
            content: const Text('L\'applicazione è aggiornata all\'ultima versione.', style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK', style: TextStyle(color: Colors.tealAccent)),
              ),
            ],
          ),
        );
      }
    }
  } catch (e) {
    debugPrint('Errore durante la verifica aggiornamento: $e');
    if (showNoUpdateDialog) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Errore', style: TextStyle(color: Colors.white)),
          content: Text('Impossibile verificare gli aggiornamenti:\n$e', style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Chiudi', style: TextStyle(color: Colors.tealAccent)),
            ),
          ],
        ),
      );
    }
  }
}
