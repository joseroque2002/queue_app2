import 'package:flutter/material.dart';
import 'dart:async';

class CountdownTimer extends StatefulWidget {
  final int duration;
  final DateTime startTime;
  final VoidCallback? onComplete;
  final VoidCallback? onTick;
  final bool isActive;

  const CountdownTimer({
    super.key,
    required this.duration,
    required this.startTime,
    this.onComplete,
    this.onTick,
    this.isActive = true,
  });

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  late Timer _timer;
  late int _remainingSeconds;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _calculateRemainingTime();
    if (widget.isActive) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(CountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _startTimer();
      } else {
        _timer.cancel();
      }
    }
  }

  void _calculateRemainingTime() {
    // Compare in UTC to avoid timezone drift (DB returns UTC timestamps)
    final now = DateTime.now().toUtc();
    final start = widget.startTime.toUtc();
    final elapsed = now.difference(start).inSeconds;
    _remainingSeconds = widget.duration - elapsed;

    if (_remainingSeconds <= 0) {
      _remainingSeconds = 0;
      _isExpired = true;
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _calculateRemainingTime();
        });

        widget.onTick?.call();

        if (_isExpired) {
          timer.cancel();
          widget.onComplete?.call();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Color _getProgressColor() {
    if (_isExpired) return Colors.red;
    if (_remainingSeconds <= 10) return Colors.orange;
    return Colors.blue;
  }

  double _getProgressValue() {
    return _remainingSeconds / widget.duration;
  }

  String _formatTime() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _getProgressColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getProgressColor(), width: 2),
      ),
      child: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: _getProgressValue(),
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor()),
            minHeight: 8,
          ),
          const SizedBox(height: 4),
          // Time display
          Text(
            _formatTime(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _getProgressColor(),
            ),
          ),
          // Status text
          Text(
            _isExpired ? 'EXPIRED' : 'COUNTDOWN',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _getProgressColor(),
            ),
          ),
        ],
      ),
    );
  }
}
