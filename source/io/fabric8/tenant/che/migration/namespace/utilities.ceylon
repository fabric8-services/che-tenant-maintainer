shared Boolean() buildTimeout(Integer timeout) {
    value end = system.milliseconds + timeout;
    return () => system.milliseconds > end;
}
shared Integer second = 1000;