import 'dart:async';
import 'dart:html' show MessagePort;

import '../stream_channel.dart';

/// A [StreamChannel] that communicates over a [MessagePort].
///
/// The remote endpoint doesn't necessarily need to be running a
/// [MessagePortChannel]. This class merely adapts a [MessagePort] as a
/// [StreamChannel].
class MessagePortChannel<T> extends StreamChannelMixin<T> {
  @override
  final Stream<T> stream;
  @override
  final StreamSink<T> sink;

  /// Creates a stream channel that communicates over [port].
  factory MessagePortChannel(MessagePort port) {
    var controller =
        StreamChannelController<T>(allowForeignErrors: false, sync: true);
    port.onMessage
        .map((message) => message.data)
        .cast<T>()
        .pipe(controller.local.sink);
    controller.local.stream.listen(port.postMessage, onDone: port.close);
    return MessagePortChannel._(
      controller.foreign.stream,
      controller.foreign.sink,
    );
  }

  MessagePortChannel._(this.stream, this.sink);
}
