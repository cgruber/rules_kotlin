package plugin.noarg

import java.lang.Exception
import org.junit.*

class UserHasNoargConstructorTest {
  @Test
  fun userShouldHaveNoargConstructor() {
    if (User::class.java.constructors.none { it.parameters.isEmpty() }) {
      throw Exception("Expected an empty constructor to exist")
    }
  }
}
