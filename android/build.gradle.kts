allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

//if error is there then this has something to do with it 
configurations.all {
    resolutionStrategy {
        force 'org.jetbrains.kotlin:kotlin-util-io:2.0.20'
        force 'org.jetbrains.kotlin:kotlin-scripting-jvm:2.0.20'
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
