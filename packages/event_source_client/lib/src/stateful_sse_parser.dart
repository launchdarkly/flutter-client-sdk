import 'dart:async';

import 'message_event.dart';

/// Enum for tracking the category of the last parsed rune.
enum _LastParsed {
  nothing,
  fieldRune,
  colonRune,
  valueRune,
  // Due to spec ambiguity in parsing lines as CRLF, LF, or CR, we need to be examining runes
  // [n] and [n-1].  To deal with this, we track the first separator rune and second saparator
  // rune as two different states.
  cr,
  lf,
}

/// This class statefully parses data provided to the [_parse] method and when warranted, emits
/// [MessageEvent]s to the provided sink.  Do not use this parser for more than one stream's
/// lifetime.  In other words, if the connection is interrupted, this parser should be discarded
/// and a new one used in its place.
class StatefulSSEParser {
  
  // Special runes for parsing
  static const _colon = 0x3A;
  static const _cr = 0x0D;
  static const _lf = 0x0A;
  static const _space = 0x20;

  // Reserved field names
  static const _fieldEvent = 'event';
  static const _fieldData = 'data';
  static const _fieldId = 'id';

  // Defaults
  static const _defaultEventType = 'message';

  // Parsing buffers
  var _lastParsed = _LastParsed.nothing;
  StringBuffer _fieldBuffer = StringBuffer();
  StringBuffer _valueBuffer = StringBuffer();

  // Event processing temporary variables
  String _id = '';
  String _eventType = '';
  StringBuffer _dataBuffer = StringBuffer();

  /// This function will iterate over the SSE stream [chunk] provided and statefully process it.
  /// When warranted, [MessageEvent]s may be sent to the provided [sink].  Subsequent calls
  /// with subsequent [chunk]s provided will be treated as a continuation of the data stream.
  void parse(String chunk, EventSink<MessageEvent> sink) {
    // switch statements are used instead of a state machine for memory and performance reasons
    chunk.runes.forEach((rune) {
      switch (_lastParsed) {
        case _LastParsed.fieldRune:
          // parsing the field
          switch (rune) {
            case _cr:
              // this terminates the line, so we can process the field and value
              _lastParsed = _LastParsed.cr;
              _processFieldAndValue();
              break;
            case _lf:
              // this terminates the line, so we can process the field and value
              _lastParsed = _LastParsed.lf;
              _processFieldAndValue();
              break;
            case _colon:
              // this colon terminates the field
              _lastParsed = _LastParsed.colonRune;
              break;
            case _space: // intentional fallthrough, exhaustively defining behavior
            default:
              // keep writing more runes into the field buffer
              _lastParsed = _LastParsed.fieldRune;
              _fieldBuffer.writeCharCode(rune);
              break;
          }
          break;
        case _LastParsed.colonRune:
          // past the colon
          switch (rune) {
            case _cr:
              // this terminates the line, so we can process the field and value
              _lastParsed = _LastParsed.cr;
              _processFieldAndValue();
              break;
            case _lf:
              // this terminates the line, so we can process the field and value
              _lastParsed = _LastParsed.lf;
              _processFieldAndValue();
              break;
            case _space:
              _lastParsed = _LastParsed.valueRune;
              // ignore first space after colon in value
              break;
            case _colon: // intentional fallthrough, exhaustively defining behavior, colons are allowed in value
            default:
              _lastParsed = _LastParsed.valueRune;
              // first rune into the value buffer
              _valueBuffer.writeCharCode(rune);
              break;
          }
          break;
        case _LastParsed.valueRune:
          // parsing the value
          switch (rune) {
            case _cr:
              // this terminates the line, so we can process the field and value
              _lastParsed = _LastParsed.cr;
              _processFieldAndValue();
              break;
            case _lf:
              // this terminates the line, so we can process the field and value
              _lastParsed = _LastParsed.lf;
              _processFieldAndValue();
              break;
            case _space: // intentional fallthrough, exhaustively defining behavior
            case _colon: // intentional fallthrough, exhaustively defining behavior
            default:
              // keep writing more runes into the value buffer
              _valueBuffer.writeCharCode(rune);
              break;
          }
          break;
        case _LastParsed.cr:
          switch (rune) {
            case _cr:
              // line is empty, so we can dispatch.  Rare case of two CRs in a row
              _lastParsed = _LastParsed.cr;
              _dispatchEvent(sink);
              break;
            case _lf:
              // do nothing here, this is the CRLF terminator case.  We already processed when we got the CR
              _lastParsed = _LastParsed.lf;
              break;
            case _colon:
              // this colon terminates the field
              _lastParsed = _LastParsed.colonRune;
              break;
            case _space: // intentional fallthrough, exhaustively defining behavior
            default:
              // First rune into the field buffer.  Strangely, space is allowed as first rune
              // of field, but not of value.
              _lastParsed = _LastParsed.fieldRune;
              _fieldBuffer.writeCharCode(rune);
              break;
          }
          break;
        case _LastParsed.nothing: // intentional fallthrough
        case _LastParsed.lf:
          // we just started parsing or just finished parsing a line previously
          switch (rune) {
            case _cr:
              // line is empty, so we can dispatch
              _lastParsed = _LastParsed.cr;
              _dispatchEvent(sink);
              break;
            case _lf:
              // line is empty, so we can dispatch.  Rare case of two LFs in a row.
              _lastParsed = _LastParsed.lf;
              _dispatchEvent(sink);
              break;
            case _colon:
              // this colon terminates the field
              _lastParsed = _LastParsed.colonRune;
              break;
            case _space: // intentional fallthrough, exhaustively defining behavior.
            default:
              // First rune into the field buffer.  Strangely, space is allowed as first rune
              // of field, but not of value.
              _lastParsed = _LastParsed.fieldRune;
              _fieldBuffer.writeCharCode(rune);
              break;
          }
          break;
      }
    });
  }

  /// This function will determine which buffer will hold the most recently parsed
  /// field and value pair and then store that data there for future dispatching.
  void _processFieldAndValue() {
    final field = _fieldBuffer.toString();
    _fieldBuffer.clear();

    final value = _valueBuffer.toString();
    _valueBuffer.clear();

    switch (field) {
      case _fieldEvent:
        _eventType = value;
        break;
      case _fieldData:
        _dataBuffer.write(value);
        _dataBuffer.write('\n');
        break;
      case _fieldId:
        // null in _id is not allowed
        if (!value.contains(String.fromCharCode(0))) {
          _id = value;
        }
        break;
      default:
      // ignored
    }
  }

  /// This function is intended to send a [MessageEvent] to the provided [sink] when invoked.
  /// There are some edge cases in which dispatching will be cancelled, such as invalid data.
  void _dispatchEvent(EventSink<MessageEvent> sink) {
    // if data is empty, ignore this dispatch and reset, but don't clear id
    if (_dataBuffer.isEmpty) {
      _eventType = '';
      return;
    }

    // create data string and remove ending newline if it exists
    var dataString = _dataBuffer.toString();
    if (dataString.endsWith('\n')) {
      dataString = dataString.substring(0,
          dataString.length - 1); // TODO: get rid of this inefficient substring
    }

    // determine which event type to use
    var eventTypeToUse = _defaultEventType;
    if (_eventType.isNotEmpty) {
      eventTypeToUse = _eventType;
    }

    // emit event to the sink
    sink.add(MessageEvent(eventTypeToUse, dataString, _id));
    _dataBuffer.clear();
    _eventType = '';
  }
}
