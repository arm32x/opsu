import java.util.Properties

plugins {
    base
}

// Read tool locations from local.properties.
val properties = Properties()
val propertiesFile = rootProject.file("local.properties")
if (propertiesFile.exists()) {
    propertiesFile.inputStream().use(properties::load)
}
val zigPath = properties["zig.path"] as String? ?: "zig"

val compileZig by tasks.registering(Exec::class) {
    val optimize = project.findProperty("zig.optimize") as String? ?: "Debug"
    commandLine = listOf(zigPath, "build", "-Doptimize=$optimize")
    workingDir = projectDir

    inputs.file("build.zig")
    inputs.file("build.zig.zon")
    inputs.dir("src")
    outputs.dir("zig-out")
}

val nativesJar by tasks.registering(Jar::class) {
    archiveBaseName = "opsu"
    archiveClassifier = "natives-all"

    destinationDirectory = project.layout.buildDirectory.dir("libs")

    from("zig-out/lib")

    inputs.files(compileZig)
}

configurations.register("nativesJar") {
    isCanBeConsumed = true
    isCanBeResolved = false
}
artifacts {
    add("nativesJar", nativesJar)
}

tasks.assemble {
    dependsOn(nativesJar)
}
