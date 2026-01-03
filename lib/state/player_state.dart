import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

final videoPlayerControllerProvider = StateProvider<VideoPlayerController?>((ref) => null);

final leftPlayerProvider = StateProvider<VideoPlayerController?>((ref) => null);
final rightPlayerProvider = StateProvider<VideoPlayerController?>((ref) => null);
