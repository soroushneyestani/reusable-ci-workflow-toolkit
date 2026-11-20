package example.ci;

/** Application entry point for the Maven consumer fixture. */
public final class Main {
  private Main() {}

  static String greeting() {
    return "hello from the Java caller";
  }

  /** Prints a deterministic greeting for the downloaded-artifact check. */
  public static void main(String[] args) {
    System.out.println(greeting());
  }
}
