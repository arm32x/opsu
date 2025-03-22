import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

plugins {
    java
    application
}

group = "itdelatrisu"
version = "0.17.0-snapshot"

// Append some build metadata to the version if building a development version
if (version.toString().endsWith("-snapshot")) {
    try {
        val commitHashProcess = ProcessBuilder("git", "rev-parse", "--short", "HEAD").directory(projectDir).start()
        val commitHash = commitHashProcess.inputStream.bufferedReader().use { it.readText() }.trim()
        val dirty = ProcessBuilder("git", "diff", "--quiet").directory(projectDir).start().waitFor() != 0
        val dirtySuffix = if (dirty) ".dirty" else ""
        version = "${version}+git.${commitHash}${dirtySuffix}"
    } catch (ex: Exception) {
        logger.warn("Unable to add Git metadata to version", ex)
    }
}

// TODO: Use SOURCE_DATE_EPOCH for reproducible builds
val buildDate = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm").format(LocalDateTime.now())

application {
    mainClass = "itdelatrisu.opsu.Opsu"
}

java {
    sourceCompatibility = JavaVersion.VERSION_1_8
    targetCompatibility = JavaVersion.VERSION_1_8
}

sourceSets["main"].java.setSrcDirs(listOf("src"))

repositories {
    mavenCentral()
    maven {
        url = uri("${rootProject.projectDir}/repo")
    }
}

dependencies {
    implementation(project(":natives", configuration = "nativesJar"))

    implementation("org.lwjgl.lwjgl:lwjgl:2.9.3") {
        exclude(group = "net.java.jinput", module = "jinput")
    }
    implementation("org.slick2d:slick2d-core:1.0.2") {
        exclude(group = "org.lwjgl.lwjgl", module = "lwjgl")
        exclude(group = "org.jcraft", module = "jorbis")
        exclude(group = "javax.jnlp", module = "jnlp-api")
    }
    implementation("net.lingala.zip4j:zip4j:1.3.2")
    implementation("com.googlecode.soundlibs:jlayer:1.0.1.4")
    implementation("com.googlecode.soundlibs:mp3spi:1.9.5.4") {
        exclude(group = "com.googlecode.soundlibs", module = "tritonus-share")
    }
    implementation("com.googlecode.soundlibs:tritonus-all:0.3.7.2")
    implementation("org.xerial:sqlite-jdbc:3.15.1")
    implementation("org.json:json:20160810")
    implementation("net.java.dev.jna:jna:4.2.2")
    implementation("net.java.dev.jna:jna-platform:4.2.2")
    implementation("org.apache.maven:maven-artifact:3.3.3")
    implementation("org.tukaani:xz:1.6")
    implementation("net.indiespot:media:0.8.9")
}

val nativePlatforms = listOf("windows", "linux", "osx", "all")
for (platform in nativePlatforms) {
    task("${platform}Natives") {
        val outputDir = project.layout.buildDirectory.dir("natives")
        inputs.files(configurations.runtimeClasspath)
        outputs.dir(outputDir)
        doLast {
            copy {
                val artifacts = configurations["runtimeClasspath"].resolvedConfiguration.resolvedArtifacts
                    .filter { it.classifier == "natives-$platform" }
                artifacts.forEach {
                    from(zipTree(it.file))
                }
                into(outputDir)
            }
        }
    }
}

tasks.processResources {
    // Make sure the version file gets regenerated if the version changes
    inputs.property("version", project.version)
    inputs.property("timestamp", buildDate)

    from("res")
    exclude("**/Thumbs.db")

    filesMatching("version") {
        expand(mapOf(
            "version" to project.version,
            "timestamp" to buildDate,
        ))
    }
}

task("unpackNatives") {
    description = "Copies native libraries to the build directory."
    dependsOn(nativePlatforms.map { "${it}Natives" }.filter { tasks[it] != null })
}

tasks.jar {
    manifest {
        attributes(mapOf(
            "Implementation-Title" to "opsu!",
            "Implementation-Version" to version,
            "Main-Class" to application.mainClass,
            "Use-XDG" to false,
        ))
    }

    duplicatesStrategy = DuplicatesStrategy.EXCLUDE
    archiveBaseName = "opsu"

    from(configurations["runtimeClasspath"].map { if (it.isDirectory) it else zipTree(it) })
    exclude("**/Thumbs.db")

    outputs.upToDateWhen { false }
}

tasks.named("classes") {
    dependsOn("unpackNatives")
}
