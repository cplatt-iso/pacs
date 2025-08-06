# Switch the base image to Ubuntu 22.04
FROM ubuntu:22.04

# Set environment variables to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Copy the .deb package into the container
COPY brit-works_6.5.0-07f_amd64.deb /tmp/brit-works.deb

# Create the user and home directory FIRST
RUN groupadd pacs && \
    useradd --create-home --home-dir /opt/pacs --shell /bin/bash -g pacs pacs && \
    echo "pacs:britsys" | chpasswd && \
    mkdir -p /opt/pacs/{db,logs,store,transactions} && \
    chown -R pacs:pacs /opt/pacs

# Install all dependencies and the package
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    sudo \
    openjdk-8-jdk \
    libcap2-bin \
    iptables \
    iproute2 \
    ssh screen unzip traceroute nmap ntp iperf p7zip-full ghostscript \
    && \
    dpkg -i /tmp/brit-works.deb && \
    rm -f /etc/init.d/pacs && \
    cp /opt/pacs/pacs /etc/init.d/pacs && \
    chmod +x /etc/init.d/pacs && \
    # Clean up
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/brit-works.deb

# --- THIS IS THE FIX ---
# Generate the self-signed certificate that the application is crying about.
# Run this as the 'pacs' user so the file has the correct ownership.
USER pacs
WORKDIR /opt/pacs
RUN /usr/lib/jvm/java-8-openjdk-amd64/jre/bin/keytool \
    -genkeypair \
    -alias works \
    -keyalg RSA \
    -keystore brit.keystore \
    -storepass password \
    -keypass password \
    -validity 3650 \
    -dname "CN=localhost, OU=IT, O=Brit, L=Nowhere, S=State, C=US"

# Expose ports for inter-container communication
EXPOSE 80 443 9080 9443 9082 3200 3222 3300 3280

# We are calling java directly, in the foreground, with the arguments stolen from that script.
CMD ["/usr/lib/jvm/java-8-openjdk-amd64/jre/bin/java", \
    "-server", \
    "-Xms1g", \
    "-Xmx1g", \
    "-XX:+ExplicitGCInvokesConcurrent", \
    "-Xloggc:logs/memory.log", \
    "-XX:+UseG1GC", \
    "-XX:+AggressiveOpts", \
    "-XX:+AlwaysPreTouch", \
    "-XX:+UseStringDeduplication", \
    "-XX:+UnlockExperimentalVMOptions", \
    "-XX:+UnlockDiagnosticVMOptions", \
    "-XX:MaxGCPauseMillis=300", \
    "-XX:SoftRefLRUPolicyMSPerMB=10", \
    "-XX:G1HeapWastePercent=20", \
    "-XX:G1ReservePercent=20", \
    "-XX:G1OldCSetRegionThresholdPercent=7", \
    "-XX:InitiatingHeapOccupancyPercent=40", \
    "-XX:+ParallelRefProcEnabled", \
    "-XX:+PrintGCDetails", \
    "-XX:+PrintReferenceGC", \
    "-XX:+PrintGCApplicationStoppedTime", \
    "-XX:+PrintAdaptiveSizePolicy", \
    "-XX:+PrintGCDateStamps", \
    "-XX:+PrintJNIGCStalls", \
    "-XX:+PrintTenuringDistribution", \
    "-XX:+G1SummarizeRSetStats", \
    "-XX:G1SummarizeRSetStatsPeriod=1", \
    "-XX:+PrintStringDeduplicationStatistics", \
    "-XX:-OmitStackTraceInFastThrow", \
    "-Dderby.drda.startNetworkServer=true", \
    "-Djava.library.path=/opt/pacs/lib", \
    "-cp", "/opt/pacs/etc:/opt/pacs/classes:/opt/pacs/lib/*", \
    "RunPacs" \
]
