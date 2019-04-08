import 'dart:async';
import 'dart:core';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_sound/android_encoder.dart';
import 'package:flutter_sound/ios_quality.dart';

class FlutterSound {
  FlutterSound() {
    _uiChannel.setMethodCallHandler((MethodCall call) {
      print('call.method: ${call.method} + ${call.arguments}');
      switch (call.method) {
        case "updateRecorderProgress":
          Map<String, dynamic> result = json.decode(call.arguments);
          _recorderController.add(RecordStatus.fromJSON(result));
          break;
        case "updateDbPeakProgress":
          _dbPeakController.add(call.arguments);
          break;
        case "updateProgress":
          Map<String, dynamic> result = jsonDecode(call.arguments);
          _playerController.add(PlayStatus.fromJSON(result));
          break;
        case "audioPlayerDidFinishPlaying":
          Map<String, dynamic> result = jsonDecode(call.arguments);
          PlayStatus status = PlayStatus.fromJSON(result);
          if (status.currentPosition != status.duration) {
            status.currentPosition = status.duration;
          }
          _playerController.add(status);
          this._isPlaying = false;
          break;
        default:
          throw ArgumentError('Unknown method ${call.method} ');
      }

      return Future.value(true);
    });
  }

  static const MethodChannel _channel = const MethodChannel('flutter_sound');
  static const MethodChannel _uiChannel =
      const MethodChannel('flutter_sound/ui');

  final StreamController<RecordStatus> _recorderController = StreamController();
  final StreamController<double> _dbPeakController = StreamController();
  final StreamController<PlayStatus> _playerController = StreamController();

  Stream<RecordStatus> _recordStatusStream;
  Stream<double> _dbPeakStream;
  Stream<PlayStatus> _playStream;

  /// Value ranges from 0 to 120
  Stream<RecordStatus> get onRecorderStateChanged =>
      _recordStatusStream ??= _recorderController.stream.asBroadcastStream();
  Stream<double> get onRecorderDbPeakChanged =>
      _dbPeakStream ??= _dbPeakController.stream.asBroadcastStream();
  Stream<PlayStatus> get onPlayerStateChanged =>
      _playStream ??= _playerController.stream.asBroadcastStream();

  bool _isRecording = false;
  bool _isPlaying = false;

  Future<String> setSubscriptionDuration(double sec) {
    return _channel
        .invokeMethod<String>('setSubscriptionDuration', <String, dynamic>{
      'sec': sec,
    });
  }

  Future<String> startRecorder(String uri,
      {int sampleRate = 44100,
      int numChannels = 2,
      int bitRate,
      AndroidEncoder androidEncoder = AndroidEncoder.AAC,
      IosQuality iosQuality = IosQuality.LOW}) async {
    try {
      String result = await _channel
          .invokeMethod<String>('startRecorder', <String, dynamic>{
        'path': uri,
        'sampleRate': sampleRate,
        'numChannels': numChannels,
        'bitRate': bitRate,
        'androidEncoder': androidEncoder?.value,
        'iosQuality': iosQuality?.value
      });

      if (this._isRecording) {
        throw Exception('Recorder is already recording.');
      }
      this._isRecording = true;
      return result;
    } catch (err) {
      throw Exception(err);
    }
  }

  Future<String> stopRecorder() async {
    if (!this._isRecording) {
      throw Exception('Recorder already stopped.');
    }

    String result = await _channel.invokeMethod<String>('stopRecorder');

    this._isRecording = false;
    return result;
  }

  Future<String> startPlayer(String uri) async {
    try {
      String result =
          await _channel.invokeMethod<String>('startPlayer', <String, dynamic>{
        'path': uri,
      });

      if (this._isPlaying) {
        throw Exception('Player is already playing.');
      }
      this._isPlaying = true;

      return result;
    } catch (err) {
      throw Exception(err);
    }
  }

  Future<String> stopPlayer() async {
    if (!this._isPlaying) {
      throw Exception('Player already stopped.');
    }
    this._isPlaying = false;

    return _channel.invokeMethod<String>('stopPlayer');
  }

  Future<String> pausePlayer() {
    return _channel.invokeMethod<String>('pausePlayer');
  }

  Future<String> resumePlayer() {
    return _channel.invokeMethod<String>('resumePlayer');
  }

  Future<String> seekToPlayer(int milliSecs) {
    return _channel.invokeMethod<String>('seekToPlayer', <String, dynamic>{
      'sec': milliSecs,
    });
  }

  Future<String> setVolume(double volume) {
    String result = '';
    if (volume < 0.0 || volume > 1.0) {
      result = 'Value of volume should be between 0.0 and 1.0.';
      return Future.value(result);
    }

    return _channel.invokeMethod<String>('setVolume', <String, dynamic>{
      'volume': volume,
    });
  }

  /// Defines the interval at which the peak level should be updated.
  /// Default is 0.8 seconds
  Future<String> setDbPeakLevelUpdate(double intervalInSecs) {
    return _channel
        .invokeMethod<String>('setDbPeakLevelUpdate', <String, dynamic>{
      'intervalInSecs': intervalInSecs,
    });
  }

  /// Enables or disables processing the Peak level in db's. Default is disabled
  Future<String> setDbLevelEnabled(bool enabled) {
    return _channel.invokeMethod<String>('setDbLevelEnabled', <String, dynamic>{
      'enabled': enabled,
    });
  }
}

class RecordStatus {
  final int currentPosition;
  final String file;

  RecordStatus.fromJSON(Map<String, dynamic> json)
      : currentPosition = json['current_position'],
        file = json['file'];

  @override
  String toString() {
    return 'currentPosition: $currentPosition, '
        'file: $file';
  }
}

class PlayStatus {
  final int duration;
  int currentPosition;
  final String file;

  PlayStatus.fromJSON(Map<String, dynamic> json)
      : duration = json['duration'],
        currentPosition = json['current_position'],
        file = json['file'];

  @override
  String toString() {
    return 'duration: $duration, '
        'currentPosition: $currentPosition, '
        'file: $file';
  }
}
