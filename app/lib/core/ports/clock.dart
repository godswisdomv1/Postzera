/// The current time, behind an interface so planners and queues can be tested
/// at any instant.
abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
