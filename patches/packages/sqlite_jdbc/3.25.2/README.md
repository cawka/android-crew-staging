## Generating NativeDB.h

    "$JAVA_HOME/bin/javac"  -source 1.5 -target 1.5 -sourcepath src/main/java -d target/common-lib src/main/java/org/sqlite/core/NativeDB.java
    "$JAVA_HOME/bin/javah" -classpath target/common-lib -jni -o target/common-lib/NativeDB.h org.sqlite.core.NativeDB

