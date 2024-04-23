document.addEventListener("DOMContentLoaded", function () {
  const finalReportData = JSON.parse(sessionStorage.getItem("reportData"));
  console.log("jsondata2 received in report.html page ", finalReportData);

  const benchmarkValues = {
    bmLook: {
      value: "15",
      description:
        "Minimum time in seconds Batchman waits before scanning and updating its production control file",
    },
    jmread: {
      value: "10",
      description:
        "Maximum time in seconds Jobman waits for a message in the courier.msg message file",
    },
    jmLook: {
      value: "300",
      description:
        "Minimum time in seconds Jobman waits before looking for completed jobs and performing general job management tasks",
    },
    nmRead: {
      value: "10",
      description:
        "Maximum time in seconds Netman waits for a connection request before checking its message queue for stop and start commands",
    },
    bmRead: {
      value: "10",
      description:
        "Maximum time in seconds Batchman waits for a message in the intercom.msg message file",
    },
    statementCacheSize: {
      value: "60",
      description:
        "Maximum number of cached prepared statements per connection",
    },

    connectionTimeout: {
      value: "180",
      description:
        "Application Request Timeout for a connection to be created from the available free pool",
    },

    maxpoolSize: {
      value: "50",
      description:
        "Maximum number of physical connections that can be created in this particular connection pool to the backend resource",
    },

    minPoolsize: {
      value: "0",
      description:
        "Minimum number of physical connections that will be kept open in the free pool",
    },

    reapTime: {
      value: "180",
      description:
        "Time interval for invoking the pool maintenance thread for closing timed out physical connections.",
    },

    selfTuningMem: {
      value: "ON",
      description:
        "Determines whether the memory tuner will dynamically distribute available memory resources between memory consumers",
    },

    APPLHEAPSZ: {
      value: "AUTOMATIC",
      description:
        "The Total amount of application memory that can be consumed by the entire application.",
    },

    DATABASE_MEMORY: {
      value: "AUTOMATIC",
      description:
        "The database memory configuration parameter specifies the size of the database memory set.",
    },

    dbHeap: {
      value: "AUTOMATIC",
      description: " Maximum amount of memory allocated for the database heap",
    },

    statHeapSz: {
      value: "AUTOMATIC",
      description:
        "Maximum size of the heap used in collecting statistics using the RUNSTATS command.",
    },

    autoRunstats: {
      value: "ON",
      description:
        "Indicates the enable or disable Flag of automatic table RUNSTATS operations for a database",
    },

    autoStmtStats: {
      value: "ON",
      description:
        "Indicates the enable and disable Flag of the collection of real-time statistics",
    },

    AUTO_REORG: {
      value: "OFF",
      description:
        "Indicates the enable or disable Flag of automatic table and index reorganization for a database",
    },

    pageAgeTrgtMcr: {
      value: "240",
      description:
        "The target duration (in seconds) for changed pages to be kept in the local buffer pool before they are persisted to table space storage",
    },

    purgePolicy: {
      value: "EntirePool",
      description:
        "Connections to destroy when a stale connection is detected in a pool",
    },

    isolationLevel: {
      value: "TRANSACTION_READ_COMMITED",
      description:
        " The data source isolation level specifies the degree of data integrity and concurrency, which in turns controls the level of database locking.",
    },
  };

  paramtersComparison(finalReportData, benchmarkValues);
  console.log("benchmark values : ", benchmarkValues);
  sessionStorage.clear();
});

function paramtersComparison(finalReportData, benchmarkValues) {
  const resultsDiv = document.getElementById("results");
  resultsDiv.innerHTML = "";
  Object.keys(benchmarkValues).forEach((key) => {
    const userValue = finalReportData[key];
    console.log("user value : ", userValue);
    const benchmarkValue = benchmarkValues[key].value;
    console.log("benchmarkvalue value : ", benchmarkValue);
    const descriptionvalue = benchmarkValues[key].description;
    const result = userValue === benchmarkValue ? "Passed" : "Failed";
    const resultClass = result === "Passed" ? "text-success" : "text-danger";
    resultsDiv.innerHTML += `
    <div class=" card ${resultClass} col-lg-6 mx-0 p-1 border border-0">
    <div class="card-body result-card h-100 w-100">
    <p class="card-title fs-4 fw-bolder " style="color: #0f62fe;">${key}</p>
    <p class="card-title fs-6 fw-normal text-dark">${descriptionvalue}</p>
    <hr class="mt-1 mb-4 mx-0">
    <p class="card-text fs-5 text-dark">System Value: <span class="fw-bolder fs-5"> ${userValue}</span></p>
      <p class="card-text fs-5 text-dark">Benchmark Value: <span class="fw-bolder fs-5"> ${benchmarkValue}</span></p>
      <p class="card-text fs-5 text-dark">Result: <span class="${resultClass} fw-bolder fs-5">${result}</span>
      </p>
      </div>
      </div>
      `;
  });
}

function downloadReport() {
  console.log("download button clicked");
  var pageContent = window.document.getElementById("container");
  /*var optionSetting = {
    margin: 0.25,
    filename: "healthCheckReport.pdf",
    image: { type: "jpeg", quality: 0.99 },
    html2canvas: {
      scale: 1,
    },
    jsPDF: { unit: "in", format: "A2", orientation: "landscape" },
  };*/
  html2pdf().from(pageContent).save();
}
