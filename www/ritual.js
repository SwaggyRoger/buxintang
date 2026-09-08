// 沉吟旁白的輪播。
//
// 原本是純 CSS：抽五句、用 nth-child 的 animation-delay 輪播。
// 問題是一次解籤要等四十秒上下，五句會在同一次等待裡轉三遍，
// 使用者看到的就是同一批台詞重複。
//
// 現在由 R 把整副句子打亂後全部送出來（四十句以上），這裡一句一句換，
// 一輪之內不重複；真的播完了才從頭來，那時候籤解早就到了。

(function () {
  var SLOT = 3400;   // 每句停留的毫秒數

  function rotate(root) {
    if (root.dataset.rotating === "1") return;   // renderUI 可能重複觸發
    root.dataset.rotating = "1";

    var items = Array.prototype.slice.call(root.children);
    if (!items.length) return;

    var i = 0;
    items[0].classList.add("is-on");

    var timer = setInterval(function () {
      // 節點被 renderUI 換掉之後就停手，免得留下孤兒 interval
      if (!root.isConnected) { clearInterval(timer); return; }
      items[i].classList.remove("is-on");
      i = (i + 1) % items.length;
      items[i].classList.add("is-on");
    }, SLOT);
  }

  function scan() {
    var nodes = document.querySelectorAll(".pondering__lines");
    for (var i = 0; i < nodes.length; i++) rotate(nodes[i]);
  }

  // 沉吟頁是 renderUI 動態插進來的，所以要盯著 DOM
  if (document.body) {
    new MutationObserver(scan).observe(document.body, { childList: true, subtree: true });
    scan();
  } else {
    document.addEventListener("DOMContentLoaded", function () {
      new MutationObserver(scan).observe(document.body, { childList: true, subtree: true });
      scan();
    });
  }
})();
