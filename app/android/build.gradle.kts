allprojects {
    repositories {
        google()
        mavenCentral()
    }

    configurations.configureEach {
        resolutionStrategy.eachDependency {
            // androidx.lifecycle 2.11 needs compileSdk 37, which Android Gradle
            // plugin 9.1 does not support. 2.10 is the newest line that builds
            // with compileSdk 36. Remove this when the plugin moves to 37.
            if (requested.group == "androidx.lifecycle" &&
                requested.version?.startsWith("2.11") == true
            ) {
                useVersion("2.10.0")
                because("2.11 requires compileSdk 37")
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
