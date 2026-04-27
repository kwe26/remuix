import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'clicks.dart';
import 'remui.dart';

class RemUIPage extends StatefulWidget {
  final String path;
  const RemUIPage({super.key, required this.path});
  @override
  State<RemUIPage> createState() => _RemUIPageState();
}

class _RemUIPageState extends State<RemUIPage> {
  late Future<Widget> _page;
  String? _errorMessage;
  bool _showError = false;
  bool _callbacksHandled = false;
  late final VoidCallback _reloadRetainListener;

  @override
  void initState() {
    super.initState();
    _reloadRetainListener = () {
      if (!mounted) {
        return;
      }
      _loadPage(applyResponseVars: false, queueCallbacks: false);
    };
    RemUI.reloadRetainTick.addListener(_reloadRetainListener);
    _loadPage();
  }

  @override
  void dispose() {
    RemUI.reloadRetainTick.removeListener(_reloadRetainListener);
    super.dispose();
  }

  Widget _withProgressOverlay(Widget child) {
    return Stack(
      children: [
        child,
        ValueListenableBuilder<int>(
          valueListenable: RemUI.progressTick,
          builder: (context, pending, _) {
            if (pending <= 0) {
              return const SizedBox.shrink();
            }

            return const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 3),
            );
          },
        ),
      ],
    );
  }

  void _loadPage({bool applyResponseVars = true, bool queueCallbacks = true}) {
    setState(() {
      _errorMessage = null;
      _showError = false;
      _callbacksHandled = false;
    });
    _page =
        RemUI.loadPage(
              widget.path,
              applyResponseVars: applyResponseVars,
              queueCallbacks: queueCallbacks,
            )
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw Exception(
                  'UI loading timeout - page took too long to load',
                );
              },
            )
            .catchError((error) {
              setState(() {
                _errorMessage = error.toString();
                _showError = true;
              });
              throw error;
            });
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('UI Loading Error'),
          content: SingleChildScrollView(
            child: SelectableText(_errorMessage ?? 'Unknown error occurred'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _loadPage();
              },
              child: const Text('Retry'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    RemUI.updateContext(context);

    // Show error dialog if there's an error
    if (_showError && _errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showErrorDialog();
        }
      });
    }

    return FutureBuilder<Widget>(
      future: _page,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _withProgressOverlay(
            Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text('Failed to load UI'),
                    const SizedBox(height: 8),
                    SelectableText(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _loadPage,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              floatingActionButton: kDebugMode
                  ? FloatingActionButton(
                      mini: true,
                      onPressed: _loadPage,
                      tooltip: 'Refresh UI',
                      child: const Icon(Icons.refresh),
                    )
                  : null,
            ),
          );
        }

        if (!snapshot.hasData) {
          return _withProgressOverlay(
            Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('Loading UI...'),
                  ],
                ),
              ),
              floatingActionButton: kDebugMode
                  ? FloatingActionButton(
                      mini: true,
                      onPressed: _loadPage,
                      tooltip: 'Refresh UI',
                      child: const Icon(Icons.refresh),
                    )
                  : null,
            ),
          );
        }

        if (!_callbacksHandled) {
          _callbacksHandled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            RemUI.runPendingCallbacks();
          });
        }

        return _withProgressOverlay(
          Stack(
            children: [
              snapshot.data!,
              if (kDebugMode)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton(
                        mini: true,
                        heroTag: 'remui-debug',
                        onPressed: RemUI.openDebugTool,
                        tooltip: 'Open RemUI Debug Tool',
                        child: const Icon(Icons.bug_report),
                      ),
                      const SizedBox(height: 12),
                      FloatingActionButton(
                        mini: true,
                        heroTag: 'remui-refresh',
                        onPressed: _loadPage,
                        tooltip: 'Refresh UI',
                        child: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class RemUIDialogPage extends StatefulWidget {
  final String path;

  const RemUIDialogPage({super.key, required this.path});

  @override
  State<RemUIDialogPage> createState() => _RemUIDialogPageState();
}

class _RemUIDialogPageState extends State<RemUIDialogPage> {
  late Future<Widget> _page;
  String? _errorMessage;
  bool _callbacksHandled = false;
  List<dynamic> _dialogCallbacks = const [];
  late final VoidCallback _reloadRetainListener;

  @override
  void initState() {
    super.initState();
    _reloadRetainListener = () {
      if (!mounted) {
        return;
      }
      _loadPage(retainState: true, queueCallbacks: false);
    };
    RemUI.reloadRetainTick.addListener(_reloadRetainListener);
    _loadPage();
  }

  @override
  void dispose() {
    RemUI.reloadRetainTick.removeListener(_reloadRetainListener);
    super.dispose();
  }

  void _loadPage({bool retainState = false, bool queueCallbacks = true}) {
    setState(() {
      _errorMessage = null;
      _callbacksHandled = false;
      _dialogCallbacks = const [];
    });
    _page = RemUI.fetchUI(widget.path)
        .then((json) {
          if (!retainState) {
            final rawVars = json['vars'];
            if (rawVars is Map<String, dynamic>) {
              RemUI.mergeVars(rawVars);
            } else if (rawVars is Map) {
              RemUI.mergeVars(
                rawVars.map((key, value) => MapEntry(key.toString(), value)),
              );
            }
          }

          final rawCallbacks = json['callbacks'];
          if (queueCallbacks && rawCallbacks is List) {
            _dialogCallbacks = List<dynamic>.from(rawCallbacks);
          }

          return RemUI.buildWidget(json);
        })
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception(
              'UI loading timeout - dialog took too long to load',
            );
          },
        )
        .catchError((error) {
          setState(() {
            _errorMessage = error.toString();
          });
          throw error;
        });
  }

  Widget _withProgressOverlay(Widget child) {
    return Stack(
      children: [
        child,
        ValueListenableBuilder<int>(
          valueListenable: RemUI.progressTick,
          builder: (context, pending, _) {
            if (pending <= 0) {
              return const SizedBox.shrink();
            }

            return const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 3),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    RemUI.updateContext(context);

    return FutureBuilder<Widget>(
      future: _page,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _withProgressOverlay(
            AlertDialog(
              title: const Text('UI Loading Error'),
              content: SingleChildScrollView(
                child: SelectableText(
                  _errorMessage ?? snapshot.error.toString(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).pop(),
                  child: const Text('Close'),
                ),
                TextButton(onPressed: _loadPage, child: const Text('Retry')),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return _withProgressOverlay(
            const Dialog(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading dialog...'),
                  ],
                ),
              ),
            ),
          );
        }

        if (!_callbacksHandled) {
          _callbacksHandled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              RemUI.runCallbacks(_dialogCallbacks);
            }
          });
        }

        return _withProgressOverlay(snapshot.data!);
      },
    );
  }
}
