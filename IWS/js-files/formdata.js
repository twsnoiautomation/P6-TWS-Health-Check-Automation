document
  .getElementById("fileuploadform")
  .addEventListener("submit", function (event) {
    event.preventDefault();

    const fileInput = document.getElementById("fileupload");
    const file = fileInput.files[0];
    console.log("file input : ", file);
    const reader = new FileReader();

    reader.onload = function (event) {
      const fileUploadData = JSON.parse(event.target.result);
      var fileUploadStatus = "file uploaded successfully..";
      reportDataProcessing(fileUploadData, fileUploadStatus);
    };
    reader.readAsText(file);
  });

document
  .getElementById("parametersForm")
  .addEventListener("submit", function (event) {
    event.preventDefault();

    const formSubmitData = {
      // section-1 parameters all input text field
      bmLook: document.getElementById("bmLook").value,
      jmread: document.getElementById("jmread").value,
      jmLook: document.getElementById("jmLook").value,
      nmRead: document.getElementById("nmRead").value,
      bmRead: document.getElementById("bmRead").value,

      // section-2 parameters
      // --> input text field
      statementCacheSize: document.getElementById("statementCacheSize").value,
      connectionTimeout: document.getElementById("connectionTimeout").value,
      maxpoolSize: document.getElementById("maxpoolSize").value,
      minPoolsize: document.getElementById("minPoolsize").value,
      reapTime: document.getElementById("reapTime").value,
      purgePolicy: document.getElementById("purgePolicy").value,
      // --> drop down menu
      isolationLevel: document.getElementById("isolationLevel").value,

      // section-3 parameters
      // --> Automatic or manual
      APPLHEAPSZ: document.getElementById("APPLHEAPSZ").checked
        ? "AUTOMATIC"
        : "NIL ( MANUAL )",
      DATABASE_MEMORY: document.getElementById("DATABASE_MEMORY").checked
        ? "AUTOMATIC"
        : "NIL ( MANUAL )",
      dbHeap: document.getElementById("dbHeap").checked
        ? "AUTOMATIC"
        : "NIL ( MANUAL )",
      statHeapSz: document.getElementById("statHeapSz").checked
        ? "AUTOMATIC"
        : "NIL ( MANUAL )",
      // --> ON or OFF
      selfTuningMem: document.getElementById("selfTuningMem").checked
        ? "ON"
        : "OFF",
      autoRunstats: document.getElementById("autoRunstats").checked
        ? "ON"
        : "OFF",
      autoStmtStats: document.getElementById("autoStmtStats").checked
        ? "ON"
        : "OFF",
      AUTO_REORG: document.getElementById("AUTO_REORG").checked ? "ON" : "OFF",

      // --> input text field
      pageAgeTrgtMcr: document.getElementById("pageAgeTrgtMcr").value,
    };
    var formSubmitStatus = "form submitted successfully..";
    reportDataProcessing(formSubmitData, formSubmitStatus);
  });

function reportDataProcessing(reportData, status) {
  console.log(status);
  console.log("Report Data : ", reportData);
  sessionStorage.setItem("reportData", JSON.stringify(reportData));
  console.log("Report data is stored successfully.");
  window.open("report.html", "_blank");
}
