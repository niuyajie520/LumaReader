plugins {
    id("org.jetbrains.kotlin.jvm")
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    testImplementation("org.junit.jupiter:junit-jupiter:5.11.3")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.test {
    useJUnitPlatform()
    // 让测试能稳稳找到仓库根的 spec/behaviour.json
    systemProperty("luma.repo.root", rootDir.parentFile.absolutePath)
    testLogging {
        events("passed", "failed", "skipped")
        showStandardStreams = false
    }
}
