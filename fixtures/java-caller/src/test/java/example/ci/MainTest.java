package example.ci;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class MainTest {
  private static final String EXPECTED = "hello from the Java caller";

  @Test
  void greetingMatchesContract() {
    assertEquals(EXPECTED, Main.greeting());
  }
}
