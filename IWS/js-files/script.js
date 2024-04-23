window.onscroll = function () {
  stickySidebar();
};

var sidebar = document.querySelector("#sidebar");
var sticky = sidebar.offsetTop;

function stickySidebar() {
  if (window.scrollY > sticky) {
    sidebar.classList.add("sticky");
  } else {
    sidebar.classList.remove("sticky");
  }
}

function productTrail() {
  const choice = document.querySelector(
    'input[name="form-option"]:checked'
  ).value;
  console.log("product button clicked with a choice of : ", choice);
  const op1 = document.querySelector(".productform");
  const op2 = document.querySelector(".productfileupload");
  if (choice == "fill-form") {
    op1.style.display = "block";
    op1.id = "reportGenerator";
    op2.style.display = "none";
  } else if (choice == "file-upload") {
    op2.style.display = "block";
    op2.id = "reportGenerator";
    op1.style.display = "none";
  }
}

/*
const form = document.getElementById("parametersForm");
form.addEventListener("submit", (e) => {
  e.preventDefault();

  console.log("section-1 of form ");
  console.log("*");
  console.log("*");
  const bmLook = document.getElementById("bmLook").value;
  const jmread = document.getElementById("jmread").value;
  const jmLook = document.getElementById("jmLook").value;
  const nmRead = document.getElementById("nmRead").value;
  const bmRead = document.getElementById("bmRead").value;
  console.log("bmLook value is : ", bmLook);
  console.log("jmread value is : ", jmread);
  console.log("jmLook value is : ", jmLook);
  console.log("nmRead value is : ", nmRead);
  console.log("bmRead value is : ", bmRead);
  console.log("*");
  const autoRunstats = document.getElementById("autoRunstats").checked
    ? "ON"
    : "OFF";
  const autoStmtStats = document.getElementById("autoStmtStats").checked
    ? "ON"
    : "OFF";
  const AUTO_REORG = document.getElementById("AUTO_REORG").checked
    ? "ON"
    : "OFF";
  const selfTuningMem = document.getElementById("selfTuningMem").checked
    ? "ON"
    : "OFF";
  console.log("autoRunstats mem has radio ", autoRunstats);
  console.log("autoStmtStats mem has radio ", autoStmtStats);
  console.log("AUTO_REORG mem has radio ", AUTO_REORG);
  console.log("selftuning mem has radio ", selfTuningMem);
  console.log("*");
  console.log("*");
  const isolationlevelValue = document.getElementById("isolationLevel").value;
  console.log("isolation level : ", isolationlevelValue);
  console.log("*");

  
  console.log("section-3 of form ");
  console.log("*");
  console.log("*");
  console.log("*");

  const isChecked1 = document.querySelector("#APPLHEAPSZ").checked;
  console.log("applheapz checked or not : ", isChecked1);
  const value1 = isChecked1 ? "AUTOMATIC" : "NIL ( MANUAL )";
  console.log("new data from APPLHEAPSZ : ", value1);

  const isChecked2 = document.querySelector("#DATABASE_MEMORY").checked;
  console.log("DATABASE_MEMORY checked or not : ", isChecked2);
  const value2 = isChecked2 ? "AUTOMATIC" : "NIL ( MANUAL )";
  console.log("new data from DATABASE_MEMORY : ", value2);

  const isChecked3 = document.querySelector("#dbHeap").checked;
  console.log("DATABASE_MEMORY checked or not : ", isChecked3);
  const value3 = isChecked3 ? "AUTOMATIC" : "NIL ( MANUAL )";
  console.log("new data from dbHeap : ", value3);

  const isChecked4 = document.querySelector("#statHeapSz").checked;
  console.log("statHeapSz checked or not : ", isChecked4);
  const value4 = isChecked4 ? "AUTOMATIC" : "NIL ( MANUAL )";
  console.log("new data from statHeapSz : ", value4);

  
});
*/
