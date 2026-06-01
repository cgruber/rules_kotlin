package greeter

fun greet(name: String): String = "hello, $name"

class Greeter(val who: String) {
    fun message(): String = greet(who)
}
