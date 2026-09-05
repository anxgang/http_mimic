// Virtual Browser Environment Polyfill for QuickJS
(function(global) {
  "use strict";

  // 1. Establish window hierarchy
  global.window = global;
  global.self = global;
  global.top = global;
  global.parent = global;
  global.name = "";
  global.innerWidth = 1920;
  global.innerHeight = 960;
  global.outerWidth = 1920;
  global.outerHeight = 1080;
  global.screenX = 0;
  global.screenY = 25;
  global.screenLeft = 0;
  global.screenTop = 25;
  global.crossOriginIsolated = false;
  global.isSecureContext = true;
  global.devicePixelRatio = 2;
  global.chrome = {
    app: { isInstalled: false, InstallState: { DISABLED: "disabled", INSTALLED: "installed", NOT_INSTALLED: "not_installed" }, RunningState: { CANNOT_RUN: "cannot_run", READY_TO_RUN: "ready_to_run", RUNNING: "running" } },
    runtime: { id: undefined }
  };

  // Helper to make functions look like native functions & shield from prototype inspection
  const nativeFnMap = new WeakMap();
  const oldFunctionToString = Function.prototype.toString;

  function patchNative(fn, name) {
    if (!fn) return fn;
    try {
      Object.defineProperty(fn, "name", { value: name, configurable: true });
    } catch(e) {}
    const nativeStr = "function " + name + "() { [native code] }";
    nativeFnMap.set(fn, nativeStr);
    try {
      fn.toString = function() { return nativeStr; };
      nativeFnMap.set(fn.toString, "function toString() { [native code] }");
    } catch(e) {}
    return fn;
  }

  Function.prototype.toString = function() {
    if (nativeFnMap.has(this)) {
      return nativeFnMap.get(this);
    }
    return oldFunctionToString.call(this);
  };
  patchNative(Function.prototype.toString, "toString");

  // V8 Error Stack Trace Helpers
  if (!Error.captureStackTrace) {
    Error.captureStackTrace = patchNative(function(targetObj, constructorOpt) {
      const err = new Error();
      targetObj.stack = err.stack;
    }, "captureStackTrace");
  }

  // Modern browser global APIs
  function fetch(input, init) {
    return Promise.resolve({
      ok: true,
      status: 200,
      statusText: "OK",
      headers: { get: function() { return null; } },
      text: patchNative(function() { return Promise.resolve(""); }, "text"),
      json: patchNative(function() { return Promise.resolve({}); }, "json"),
      blob: patchNative(function() { return Promise.resolve({}); }, "blob")
    });
  }
  patchNative(fetch, "fetch");
  global.fetch = fetch;

  function Notification(title, options) {
    this.title = String(title || "");
  }
  Notification.permission = "default";
  Notification.requestPermission = patchNative(function() {
    return Promise.resolve("default");
  }, "requestPermission");
  patchNative(Notification, "Notification");
  global.Notification = Notification;

  const speechSynthesis = {
    pending: false,
    speaking: false,
    paused: false,
    onvoiceschanged: null,
    getVoices: patchNative(function() { return []; }, "getVoices"),
    speak: patchNative(function() {}, "speak"),
    cancel: patchNative(function() {}, "cancel"),
    pause: patchNative(function() {}, "pause"),
    resume: patchNative(function() {}, "resume"),
    addEventListener: patchNative(function() {}, "addEventListener"),
    removeEventListener: patchNative(function() {}, "removeEventListener"),
    dispatchEvent: patchNative(function() { return true; }, "dispatchEvent")
  };
  Object.defineProperty(global, "speechSynthesis", { value: speechSynthesis, writable: true, configurable: true });

  // 2. Base Prototypes & WebIDL hierarchy
  function EventTarget() {}
  function Node() {}
  function Element() {}
  function HTMLElement() {}
  function HTMLDocument() {}
  function Document() {}
  function Window() {}

  Object.setPrototypeOf(Node.prototype, EventTarget.prototype);
  Object.setPrototypeOf(Element.prototype, Node.prototype);
  Object.setPrototypeOf(HTMLElement.prototype, Element.prototype);
  Object.setPrototypeOf(Document.prototype, Node.prototype);
  Object.setPrototypeOf(HTMLDocument.prototype, Document.prototype);

  patchNative(EventTarget, "EventTarget");
  patchNative(Node, "Node");
  patchNative(Element, "Element");
  patchNative(HTMLElement, "HTMLElement");
  patchNative(Document, "Document");
  patchNative(HTMLDocument, "HTMLDocument");
  patchNative(Window, "Window");

  global.EventTarget = EventTarget;
  global.Node = Node;
  global.Element = Element;
  global.HTMLElement = HTMLElement;
  global.Document = Document;
  global.HTMLDocument = HTMLDocument;
  global.Window = Window;

  // Generic constructor generator
  const genericConstructors = [
    "HTMLDivElement", "HTMLSpanElement", "HTMLImageElement", "HTMLAnchorElement",
    "HTMLHeadElement", "HTMLBodyElement", "HTMLScriptElement", "HTMLStyleElement",
    "HTMLLinkElement", "HTMLMetaElement", "HTMLTitleElement", "HTMLParagraphElement",
    "HTMLHeadingElement", "HTMLInputElement", "HTMLButtonElement", "HTMLFormElement",
    "HTMLSelectElement", "HTMLOptionElement", "HTMLTextAreaElement", "HTMLTableElement",
    "HTMLTableRowElement", "HTMLTableCellElement", "HTMLAudioElement", "HTMLVideoElement",
    "HTMLIFrameElement", "HTMLCanvasElement", "CanvasRenderingContext2D", "WebGLRenderingContext",
    "WebGL2RenderingContext", "AudioContext", "webkitAudioContext", "OfflineAudioContext",
    "AudioBuffer", "AudioNode", "GainNode", "OscillatorNode", "DynamicsCompressorNode",
    "AnalyserNode", "Event", "CustomEvent", "UIEvent", "MouseEvent", "KeyboardEvent",
    "TouchEvent", "PointerEvent", "FocusEvent", "InputEvent", "WheelEvent",
    "DeviceOrientationEvent", "DeviceMotionEvent", "Performance", "PerformanceEntry",
    "PerformanceNavigationTiming", "PerformanceResourceTiming", "Storage", "File",
    "FileList", "FileReader", "Blob", "FormData", "Headers", "Request", "Response",
    "AbortController", "AbortSignal", "WebSocket", "Worker", "SharedWorker", "ServiceWorker",
    "MutationObserver", "IntersectionObserver", "ResizeObserver", "PerformanceObserver",
    "URLSearchParams", "DOMParser", "XMLSerializer", "XPathEvaluator", "XPathResult",
    "MediaStream", "RTCPeerConnection", "IDBFactory", "IDBDatabase", "Cache", "CacheStorage",
    "Credential", "CredentialsContainer", "Navigator", "Screen", "History", "Location",
    "BarProp", "VisualViewport", "SpeechSynthesis", "SpeechSynthesisUtterance",
    "PaymentRequest", "Bluetooth", "USB", "HID", "Serial", "XRSystem", "WakeLock",
    "Geolocation", "BatteryManager", "NetworkInformation", "Permissions", "PermissionStatus"
  ];

  genericConstructors.forEach(name => {
    if (typeof global[name] === "undefined") {
      function Ctor() {}
      Ctor.prototype = Object.create(HTMLElement.prototype);
      Ctor.prototype.constructor = Ctor;
      patchNative(Ctor, name);
      global[name] = Ctor;
    }
  });

  function parseUrlComponents(urlString, baseUrl) {
    let str = String(urlString || "");
    if (!str.startsWith("http://") && !str.startsWith("https://")) {
      const base = baseUrl || (typeof location !== "undefined" ? location.href : (global.__TARGET_URL__ || "http://localhost/"));
      if (str.startsWith("//")) {
        const proto = (typeof location !== "undefined" ? location.protocol : "https:");
        str = proto + str;
      } else if (str.startsWith("/")) {
        const orig = (typeof location !== "undefined" ? location.origin : "http://localhost");
        str = orig + str;
      } else {
        const orig = (typeof location !== "undefined" ? location.origin : "http://localhost");
        str = orig + "/" + str;
      }
    }
    const match = str.match(/^(https?:)\/\/([^/:?#]+)(?::(\d+))?([^?#]*)(?:\?([^#]*))?(?:#(.*))?$/);
    if (!match) return { href: str, protocol: "https:", host: "", hostname: "", port: "", pathname: "/", search: "", hash: "", origin: "" };
    const proto = match[1];
    const hostName = match[2];
    const portNum = match[3] || "";
    const fullHost = portNum ? `${hostName}:${portNum}` : hostName;
    return {
      href: str,
      protocol: proto,
      hostname: hostName,
      port: portNum,
      host: fullHost,
      origin: `${proto}//${fullHost}`,
      pathname: match[4] || "/",
      search: match[5] ? `?${match[5]}` : "",
      hash: match[6] ? `#${match[6]}` : ""
    };
  }

  function MockURL(url, base) {
    const p = parseUrlComponents(url, base);
    Object.assign(this, p);
    this.toString = function() { return this.href; };
  }
  patchNative(MockURL, "URL");
  global.URL = MockURL;

  // 3. Location object
  const currentUrl = global.__TARGET_URL__ || "http://localhost/";
  const parsedUrl = parseUrlComponents(currentUrl);

  const location = {
    ...parsedUrl,
    assign: patchNative(function(url) {}, "assign"),
    replace: patchNative(function(url) {}, "replace"),
    reload: patchNative(function() {}, "reload"),
    toString: patchNative(function() { return this.href; }, "toString")
  };
  Object.defineProperty(global, "location", { value: location, writable: true, configurable: true });

  const history = {
    length: 1,
    scrollRestoration: "auto",
    state: null,
    back: patchNative(function() {}, "back"),
    forward: patchNative(function() {}, "forward"),
    go: patchNative(function(delta) {}, "go"),
    pushState: patchNative(function(state, title, url) { this.state = state; }, "pushState"),
    replaceState: patchNative(function(state, title, url) { this.state = state; }, "replaceState")
  };
  Object.defineProperty(global, "history", { value: history, writable: true, configurable: true });

  // 4. Navigator object
  const defaultUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36";
  const userAgent = global.__USER_AGENT__ || defaultUA;
  const isAndroid = userAgent.includes("Android");
  const isIOS = userAgent.includes("iPhone") || userAgent.includes("iPad");
  const isMobile = isAndroid || isIOS || userAgent.includes("Mobile");

  const platform = global.__PLATFORM__ || (userAgent.includes("Win") ? "Win32" : (isAndroid ? "Linux armv8l" : (isIOS ? "iPhone" : "MacIntel")));
  const language = global.__LANGUAGE__ || "en-US";

  if (isMobile) {
    global.innerWidth = 412;
    global.innerHeight = 823;
    global.outerWidth = 412;
    global.outerHeight = 915;
    global.screenX = 0;
    global.screenY = 0;
    global.screenLeft = 0;
    global.screenTop = 0;
    global.devicePixelRatio = 2.625;
    global.ontouchstart = null;
    global.ontouchend = null;
    global.ontouchmove = null;
    global.ontouchcancel = null;
  }

  const navigator = {
    userAgent: userAgent,
    appVersion: userAgent.replace(/^Mozilla\//, ""),
    appName: "Netscape",
    appCodeName: "Mozilla",
    platform: platform,
    product: "Gecko",
    productSub: "20030107",
    vendor: userAgent.includes("Chrome") || userAgent.includes("Chromium") ? "Google Inc." : (userAgent.includes("Apple") ? "Apple Computer, Inc." : ""),
    vendorSub: "",
    language: language,
    languages: Object.freeze([language, language.split("-")[0]].filter(Boolean)),
    cookieEnabled: true,
    hardwareConcurrency: 8,
    deviceMemory: 8,
    webdriver: false,
    maxTouchPoints: isMobile ? 5 : 0,
    onLine: true,
    doNotTrack: null,
    plugins: (function() {
      const list = isMobile ? [] : [
        { name: "PDF Viewer", filename: "internal-pdf-viewer", description: "Portable Document Format" },
        { name: "Chrome PDF Viewer", filename: "internal-pdf-viewer", description: "Portable Document Format" },
        { name: "Chromium PDF Viewer", filename: "internal-pdf-viewer", description: "Portable Document Format" },
        { name: "Microsoft Edge PDF Viewer", filename: "internal-pdf-viewer", description: "Portable Document Format" },
        { name: "WebKit built-in PDF", filename: "internal-pdf-viewer", description: "Portable Document Format" }
      ];
      list.item = patchNative(function(i) { return list[i] || null; }, "item");
      list.namedItem = patchNative(function(name) { return list.find(p => p.name === name) || null; }, "namedItem");
      list.refresh = patchNative(function() {}, "refresh");
      return Object.freeze(list);
    })(),
    mimeTypes: (function() {
      const list = isMobile ? [] : [
        { type: "application/pdf", suffixes: "pdf", description: "Portable Document Format" },
        { type: "text/pdf", suffixes: "pdf", description: "Portable Document Format" }
      ];
      list.item = patchNative(function(i) { return list[i] || null; }, "item");
      list.namedItem = patchNative(function(type) { return list.find(m => m.type === type) || null; }, "namedItem");
      return Object.freeze(list);
    })(),
    connection: {
      effectiveType: "4g",
      rtt: 50,
      downlink: 10,
      saveData: false,
      addEventListener: patchNative(function() {}, "addEventListener")
    },
    mediaDevices: {
      enumerateDevices: patchNative(function() {
        return Promise.resolve([
          { deviceId: "default", kind: "audioinput", label: "", groupId: "f7a39d8e" },
          { deviceId: "default", kind: "videoinput", label: "", groupId: "f7a39d8e" },
          { deviceId: "default", kind: "audiooutput", label: "", groupId: "f7a39d8e" }
        ]);
      }, "enumerateDevices"),
      addEventListener: patchNative(function() {}, "addEventListener"),
      removeEventListener: patchNative(function() {}, "removeEventListener"),
      dispatchEvent: patchNative(function() { return true; }, "dispatchEvent")
    },
    permissions: {
      query: patchNative(function(desc) {
        const name = (desc && desc.name) || "";
        let state = "granted";
        if (name === "notifications" || name === "geolocation" || name === "camera" || name === "microphone") {
          state = "prompt";
        }
        return Promise.resolve({
          state: state,
          name: name,
          onchange: null,
          addEventListener: patchNative(function() {}, "addEventListener"),
          removeEventListener: patchNative(function() {}, "removeEventListener"),
          dispatchEvent: patchNative(function() { return true; }, "dispatchEvent")
        });
      }, "query")
    },
    userAgentData: {
      brands: Object.freeze([
        { brand: "Chromium", version: (userAgent.match(/Chrome\/(\d+)/) || [null, "131"])[1] },
        { brand: "Not?A_Brand", version: "24" },
        { brand: "Google Chrome", version: (userAgent.match(/Chrome\/(\d+)/) || [null, "131"])[1] }
      ]),
      mobile: isMobile,
      platform: isAndroid ? "Android" : (isIOS ? "iOS" : (platform.includes("Win") ? "Windows" : (platform.includes("Linux") ? "Linux" : "macOS"))),
      getHighEntropyValues: patchNative(function(hints) {
        const ver = (userAgent.match(/Chrome\/(\d+)/) || [null, "131"])[1];
        const fullVer = ver + ".0.6778.86";
        return Promise.resolve({
          architecture: isMobile ? "arm" : "x86",
          bitness: "64",
          brands: this.brands,
          fullVersionList: [
            { brand: "Chromium", version: fullVer },
            { brand: "Not?A_Brand", version: "24.0.0.0" },
            { brand: "Google Chrome", version: fullVer }
          ],
          mobile: this.mobile,
          model: isAndroid ? "K" : "",
          platform: this.platform,
          platformVersion: isAndroid ? "10.0.0" : "13.6.9",
          uaFullVersion: fullVer
        });
      }, "getHighEntropyValues"),
      toJSON: patchNative(function() {
        return { brands: this.brands, mobile: this.mobile, platform: this.platform };
      }, "toJSON")
    },
    getBattery: patchNative(function() {
      return Promise.resolve({
        charging: true,
        chargingTime: 0,
        dischargingTime: Infinity,
        level: 1,
        addEventListener: patchNative(function() {}, "addEventListener")
      });
    }, "getBattery"),
    javaEnabled: patchNative(function() { return false; }, "javaEnabled"),
    vibrate: patchNative(function() { return true; }, "vibrate")
  };
  Object.defineProperty(global, "navigator", { value: navigator, writable: true, configurable: true });

  // 5. Screen object
  const screen = isMobile ? {
    width: 412,
    height: 915,
    availWidth: 412,
    availHeight: 915,
    colorDepth: 24,
    pixelDepth: 24,
    availLeft: 0,
    availTop: 0,
    orientation: { type: "portrait-primary", angle: 0, addEventListener: function() {} }
  } : {
    width: 1920,
    height: 1080,
    availWidth: 1920,
    availHeight: 1055,
    colorDepth: 24,
    pixelDepth: 24,
    availLeft: 0,
    availTop: 25,
    orientation: { type: "landscape-primary", angle: 0, addEventListener: function() {} }
  };
  Object.defineProperty(global, "screen", { value: screen, writable: true, configurable: true });

  // 6. DOM Element Factory & Authentic Font Metrics
  const REAL_FONT_METRICS = {
    "monospace": { "12px": [94, 14], "14px": [110, 16], "16px": [125, 19], "20px": [157, 24], "24px": [188, 28], "32px": [250, 38], "72px": [564, 84] },
    "sans-serif": { "12px": [111, 17], "14px": [130, 20], "16px": [148, 22], "20px": [186, 28], "24px": [223, 33], "32px": [297, 45], "72px": [668, 100] },
    "serif": { "12px": [104, 17], "14px": [121, 20], "16px": [139, 22], "20px": [173, 28], "24px": [208, 33], "32px": [277, 45], "72px": [624, 100] },
    "Arial": { "12px": [108, 14], "14px": [126, 16], "16px": [144, 19], "20px": [180, 24], "24px": [216, 28], "32px": [288, 38], "72px": [648, 84] },
    "Times New Roman": { "12px": [104, 14], "14px": [121, 16], "16px": [139, 19], "20px": [173, 24], "24px": [208, 28], "32px": [277, 38], "72px": [624, 84] },
    "Courier New": { "12px": [101, 14], "14px": [118, 16], "16px": [135, 19], "20px": [168, 24], "24px": [202, 28], "32px": [269, 38], "72px": [605, 84] },
    "Helvetica": { "12px": [108, 14], "14px": [126, 16], "16px": [144, 19], "20px": [180, 24], "24px": [216, 28], "32px": [288, 38], "72px": [648, 84] },
    "Verdana": { "12px": [116, 15], "14px": [135, 17], "16px": [154, 20], "20px": [193, 25], "24px": [232, 29], "32px": [309, 39], "72px": [695, 87] },
    "Georgia": { "12px": [109, 14], "14px": [127, 16], "16px": [145, 19], "20px": [182, 24], "24px": [218, 28], "32px": [291, 38], "72px": [655, 84] },
    "Impact": { "12px": [82, 15], "14px": [96, 17], "16px": [109, 20], "20px": [137, 25], "24px": [164, 29], "32px": [219, 39], "72px": [492, 87] },
    "Trebuchet MS": { "12px": [106, 14], "14px": [124, 16], "16px": [141, 19], "20px": [177, 24], "24px": [212, 28], "32px": [283, 38], "72px": [637, 84] },
    "Tahoma": { "12px": [109, 15], "14px": [127, 17], "16px": [145, 20], "20px": [182, 25], "24px": [218, 29], "32px": [291, 39], "72px": [655, 87] }
  };

  const eventListeners = {};
  const trackedScripts = [];
  function addEventListener(type, listener) {
    if (!eventListeners[type]) eventListeners[type] = [];
    eventListeners[type].push(listener);
  }
  function removeEventListener(type, listener) {
    if (!eventListeners[type]) return;
    eventListeners[type] = eventListeners[type].filter(l => l !== listener);
  }
  function dispatchEvent(evt) {
    const list = eventListeners[evt.type] || [];
    list.forEach(fn => { try { fn(evt); } catch(e) {} });
  }

  const elementsById = {};

  function createMockElement(tagName) {
    const tag = tagName.toLowerCase();
    const children = [];
    const attributes = {};
    const style = { display: "block", visibility: "visible" };

    const el = {
      tagName: tagName.toUpperCase(),
      nodeName: tagName.toUpperCase(),
      nodeType: 1,
      style: style,
      children: children,
      childNodes: children,
      parentNode: null,
      clientWidth: tag === "body" || tag === "html" ? 1920 : 300,
      clientHeight: tag === "body" || tag === "html" ? 1080 : 150,
      offsetWidth: tag === "body" || tag === "html" ? 1920 : 300,
      offsetHeight: tag === "body" || tag === "html" ? 1080 : 150,
      offsetLeft: 0,
      offsetTop: 0,
      id: "",
      className: "",
      innerHTML: "",
      innerText: "",
      textContent: "",
      setAttribute: patchNative(function(k, v) {
        attributes[k] = String(v);
        if (k === "id") {
          el.id = String(v);
          elementsById[el.id] = el;
        }
      }, "setAttribute"),
      getAttribute: patchNative(function(k) { return attributes[k] || null; }, "getAttribute"),
      hasAttribute: patchNative(function(k) { return k in attributes; }, "hasAttribute"),
      removeAttribute: patchNative(function(k) {
        delete attributes[k];
        if (k === "id") { delete elementsById[el.id]; el.id = ""; }
      }, "removeAttribute"),
      appendChild: patchNative(function(child) {
        if (child) {
          child.parentNode = el;
          children.push(child);
        }
        return child;
      }, "appendChild"),
      removeChild: patchNative(function(child) {
        const idx = children.indexOf(child);
        if (idx !== -1) {
          children.splice(idx, 1);
          if (child) child.parentNode = null;
        }
        return child;
      }, "removeChild"),
      remove: patchNative(function() {
        if (el.parentNode) {
          el.parentNode.removeChild(el);
        }
      }, "remove"),
      contains: patchNative(function(child) {
        return children.includes(child);
      }, "contains"),
      insertBefore: patchNative(function(node) {
        if (node) {
          node.parentNode = el;
          children.push(node);
        }
        return node;
      }, "insertBefore"),
      addEventListener: patchNative(addEventListener, "addEventListener"),
      removeEventListener: patchNative(removeEventListener, "removeEventListener"),
      dispatchEvent: patchNative(dispatchEvent, "dispatchEvent"),
      getBoundingClientRect: patchNative(function() {
        return { top: 0, left: 0, right: 300, bottom: 150, width: 300, height: 150, x: 0, y: 0 };
      }, "getBoundingClientRect"),
      getElementsByTagName: patchNative(function(t) {
        const lower = (t || "").toLowerCase();
        if (lower === "script") return trackedScripts.length > 0 ? trackedScripts : [createMockElement("script")];
        return [];
      }, "getElementsByTagName")
    };

    if (tag === "a") {
      let _href = "";
      Object.defineProperty(el, "href", {
        get() { return _href; },
        set(val) {
          _href = String(val);
          attributes["href"] = _href;
          try {
            const u = new URL(_href, location.href);
            el.protocol = u.protocol;
            el.host = u.host;
            el.hostname = u.hostname;
            el.port = u.port;
            el.pathname = u.pathname;
            el.search = u.search;
            el.hash = u.hash;
            el.origin = u.origin;
          } catch(e) {}
        }
      });
      el.protocol = location.protocol;
      el.host = location.host;
      el.hostname = location.hostname;
      el.port = location.port;
      el.pathname = "/";
      el.search = "";
      el.hash = "";
      el.origin = location.origin;
    }

    if (tag === "script") {
      el.src = "";
      trackedScripts.push(el);
    }

    Object.defineProperty(el, "offsetWidth", {
      get: function() {
        const family = el.style.fontFamily || "sans-serif";
        const size = el.style.fontSize || "16px";
        for (const font in REAL_FONT_METRICS) {
          if (family.includes(font)) {
            const match = REAL_FONT_METRICS[font][size] || REAL_FONT_METRICS[font]["16px"];
            return match ? match[0] : 148;
          }
        }
        return 148;
      },
      configurable: true
    });

    Object.defineProperty(el, "offsetHeight", {
      get: function() {
        const family = el.style.fontFamily || "sans-serif";
        const size = el.style.fontSize || "16px";
        for (const font in REAL_FONT_METRICS) {
          if (family.includes(font)) {
            const match = REAL_FONT_METRICS[font][size] || REAL_FONT_METRICS[font]["16px"];
            return match ? match[1] : 22;
          }
        }
        return 22;
      },
      configurable: true
    });

    if (tag === "canvas") {
      el.getContext = patchNative(function(type) {
        if (type === "2d") {
          return {
            canvas: el,
            fillStyle: "#000",
            strokeStyle: "#000",
            font: "10px sans-serif",
            textBaseline: "alphabetic",
            textAlign: "start",
            fillText: patchNative(function() {}, "fillText"),
            strokeText: patchNative(function() {}, "strokeText"),
            fillRect: patchNative(function() {}, "fillRect"),
            clearRect: patchNative(function() {}, "clearRect"),
            beginPath: patchNative(function() {}, "beginPath"),
            arc: patchNative(function() {}, "arc"),
            closePath: patchNative(function() {}, "closePath"),
            fill: patchNative(function() {}, "fill"),
            stroke: patchNative(function() {}, "stroke"),
            measureText: patchNative(function(txt) {
              return { width: (txt || "").length * 8, actualBoundingBoxAscent: 10, actualBoundingBoxDescent: 2 };
            }, "measureText"),
            getImageData: patchNative(function(x, y, w, h) {
              const width = w || 16;
              const height = h || 16;
              const len = width * height * 4;
              const data = new Uint8ClampedArray(len);
              for (let i = 0; i < len; i += 4) {
                const pixelIndex = i / 4;
                const px = pixelIndex % width;
                const py = Math.floor(pixelIndex / width);
                data[i] = (px > 2 && px < 14 && py > 2 && py < 14) ? 255 : 10;
                data[i + 1] = (px > 4 && py > 4) ? 102 : 20;
                data[i + 2] = (px * 13 + py * 17) % 256;
                data[i + 3] = 255;
              }
              return { data: data, width: width, height: height };
            }, "getImageData"),
            save: patchNative(function() {}, "save"),
            restore: patchNative(function() {}, "restore")
          };
        }
        if (type && type.includes("webgl")) {
          const gl = {
            canvas: el,
            _clearR: 0.8,
            _clearG: 0.4,
            _clearB: 0.2,
            _clearA: 1.0,
            VERTEX_SHADER: 35633,
            FRAGMENT_SHADER: 35632,
            COMPILE_STATUS: 35713,
            LINK_STATUS: 35714,
            COLOR_BUFFER_BIT: 16384,
            DEPTH_BUFFER_BIT: 256,
            TRIANGLES: 4,
            FLOAT: 5126,
            RGBA: 6408,
            UNSIGNED_BYTE: 5121,
            HIGH_FLOAT: 36338,
            MEDIUM_FLOAT: 36337,
            LOW_FLOAT: 36336,
            HIGH_INT: 36341,
            MEDIUM_INT: 36340,
            LOW_INT: 36339,
            ARRAY_BUFFER: 34962,
            STATIC_DRAW: 35044,
            UNPACK_FLIP_Y_WEBGL: 37440,
            TEXTURE_2D: 3553,
            MAX_TEXTURE_SIZE: 16384,
            MAX_VIEWPORT_DIMS: 3386,
            VENDOR: 7936,
            RENDERER: 7937,
            VERSION: 7938,
            SHADING_LANGUAGE_VERSION: 35724,

            getParameter: patchNative(function(param) {
              if (param === 0x9245 || param === 37445) return isAndroid ? "Qualcomm" : "Google Inc. (Intel)";
              if (param === 0x9246 || param === 37446) return isAndroid ? "Adreno (TM) 640" : "ANGLE (Intel, ANGLE Metal Renderer: Intel(R) UHD Graphics 630, Unspecified Version)";
              if (param === 7936) return "WebKit";
              if (param === 7937) return "WebKit WebGL";
              if (param === 7938) return "WebGL 1.0 (OpenGL ES 2.0 Chromium)";
              if (param === 35724) return "WebGL GLSL ES 1.0 (OpenGL ES GLSL ES 1.0 Chromium)";
              if (param === 3379) return 16384; // MAX_TEXTURE_SIZE
              if (param === 3386) return new Int32Array([16384, 16384]); // MAX_VIEWPORT_DIMS
              if (param === 34076) return 16384; // MAX_CUBE_MAP_TEXTURE_SIZE
              if (param === 34921) return 16; // MAX_VERTEX_ATTRIBS
              if (param === 34930) return 16; // MAX_TEXTURE_IMAGE_UNITS
              if (param === 35661) return 32; // MAX_COMBINED_TEXTURE_IMAGE_UNITS
              if (param === 36347) return 1024; // MAX_FRAGMENT_UNIFORM_VECTORS
              if (param === 36348) return 1024; // MAX_VERTEX_UNIFORM_VECTORS
              if (param === 36349) return 30; // MAX_VARYING_VECTORS
              if (param === 34024) return 16384; // MAX_RENDERBUFFER_SIZE
              if (param === 35373) return 16; // MAX_VERTEX_TEXTURE_IMAGE_UNITS
              if (param === 33901) return new Float32Array([1, 511]); // ALIASED_POINT_SIZE_RANGE
              if (param === 33902) return new Float32Array([1, 1]); // ALIASED_LINE_WIDTH_RANGE
              return 0;
            }, "getParameter"),
            getExtension: patchNative(function(ext) {
              if (ext === "WEBGL_debug_renderer_info") {
                return { UNMASKED_VENDOR_WEBGL: 37445, UNMASKED_RENDERER_WEBGL: 37446 };
              }
              if (ext === "EXT_texture_filter_anisotropic") {
                return { MAX_TEXTURE_MAX_ANISOTROPY_EXT: 34047 };
              }
              return {};
            }, "getExtension"),
            getSupportedExtensions: patchNative(function() {
              return [
                "ANGLE_instanced_arrays",
                "EXT_blend_minmax",
                "EXT_clip_control",
                "EXT_color_buffer_half_float",
                "EXT_depth_clamp",
                "EXT_disjoint_timer_query",
                "EXT_float_blend",
                "EXT_frag_depth",
                "EXT_polygon_offset_clamp",
                "EXT_shader_texture_lod",
                "EXT_texture_compression_bptc",
                "EXT_texture_compression_rgtc",
                "EXT_texture_filter_anisotropic",
                "EXT_texture_mirror_clamp_to_edge",
                "EXT_sRGB",
                "KHR_parallel_shader_compile",
                "OES_element_index_uint",
                "OES_fbo_render_mipmap",
                "OES_standard_derivatives",
                "OES_texture_float",
                "OES_texture_float_linear",
                "OES_texture_half_float",
                "OES_texture_half_float_linear",
                "OES_vertex_array_object",
                "WEBGL_blend_func_extended",
                "WEBGL_color_buffer_float",
                "WEBGL_compressed_texture_s3tc",
                "WEBGL_compressed_texture_s3tc_srgb",
                "WEBGL_debug_renderer_info",
                "WEBGL_debug_shaders",
                "WEBGL_depth_texture",
                "WEBGL_draw_buffers",
                "WEBGL_lose_context",
                "WEBGL_multi_draw",
                "WEBGL_polygon_mode"
              ];
            }, "getSupportedExtensions"),
            getShaderPrecisionFormat: patchNative(function(shaderType, precisionType) {
              return { precision: 23, rangeMin: 127, rangeMax: 127 };
            }, "getShaderPrecisionFormat"),
            createShader: patchNative(function(type) {
              return { type: type, source: "", compiled: true };
            }, "createShader"),
            shaderSource: patchNative(function(shader, src) {
              if (shader) shader.source = src;
            }, "shaderSource"),
            compileShader: patchNative(function(shader) {
              if (shader) shader.compiled = true;
            }, "compileShader"),
            getShaderParameter: patchNative(function(shader, param) {
              return true;
            }, "getShaderParameter"),
            getShaderInfoLog: patchNative(function() { return ""; }, "getShaderInfoLog"),
            createProgram: patchNative(function() {
              return { shaders: [], linked: true };
            }, "createProgram"),
            attachShader: patchNative(function(prog, shader) {
              if (prog && shader) prog.shaders.push(shader);
            }, "attachShader"),
            linkProgram: patchNative(function(prog) {
              if (prog) prog.linked = true;
            }, "linkProgram"),
            getProgramParameter: patchNative(function(prog, param) {
              return true;
            }, "getProgramParameter"),
            getProgramInfoLog: patchNative(function() { return ""; }, "getProgramInfoLog"),
            useProgram: patchNative(function() {}, "useProgram"),
            getAttribLocation: patchNative(function(prog, name) { return 0; }, "getAttribLocation"),
            getUniformLocation: patchNative(function(prog, name) { return {}; }, "getUniformLocation"),
            enableVertexAttribArray: patchNative(function(idx) {}, "enableVertexAttribArray"),
            vertexAttribPointer: patchNative(function() {}, "vertexAttribPointer"),
            createBuffer: patchNative(function() { return {}; }, "createBuffer"),
            bindBuffer: patchNative(function() {}, "bindBuffer"),
            bufferData: patchNative(function() {}, "bufferData"),
            viewport: patchNative(function(x, y, w, h) {}, "viewport"),
            clearColor: patchNative(function(r, g, b, a) {
              gl._clearR = r;
              gl._clearG = g;
              gl._clearB = b;
              gl._clearA = a;
            }, "clearColor"),
            clear: patchNative(function(mask) {}, "clear"),
            drawArrays: patchNative(function(mode, first, count) {}, "drawArrays"),
            drawElements: patchNative(function() {}, "drawElements"),
            createTexture: patchNative(function() { return {}; }, "createTexture"),
            bindTexture: patchNative(function() {}, "bindTexture"),
            texParameteri: patchNative(function() {}, "texParameteri"),
            texImage2D: patchNative(function() {}, "texImage2D"),
            readPixels: patchNative(function(x, y, w, h, format, type, pixels) {
              if (pixels && pixels.length) {
                const r = gl._clearR !== undefined ? Math.round(gl._clearR * 255) : 204;
                const g = gl._clearG !== undefined ? Math.round(gl._clearG * 255) : 102;
                const b = gl._clearB !== undefined ? Math.round(gl._clearB * 255) : 51;
                const a = gl._clearA !== undefined ? Math.round(gl._clearA * 255) : 255;
                for (let i = 0; i < pixels.length; i += 4) {
                  pixels[i] = r;
                  pixels[i + 1] = g;
                  pixels[i + 2] = b;
                  pixels[i + 3] = a;
                }
              }
            }, "readPixels")
          };
          return gl;
        }
        return null;
      }, "getContext");

      el.toDataURL = patchNative(function() {
        return "data:image/png;base64,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";
      }, "toDataURL");
    }

    return el;
  }

  // 7. Document object
  const document = {
    readyState: "complete",
    compatMode: "CSS1Compat",
    characterSet: "UTF-8",
    contentType: "text/html",
    doctype: { name: "html" },
    location: location,
    URL: location.href,
    documentURI: location.href,
    referrer: global.__REFERRER__ || "",
    cookie: global.__INITIAL_COOKIES__ || "",
    title: global.__DOCUMENT_TITLE__ || "",
    hidden: false,
    visibilityState: "visible",
    hasFocus: patchNative(function() { return true; }, "hasFocus"),
    documentElement: createMockElement("html"),
    head: createMockElement("head"),
    body: createMockElement("body"),
    createElement: patchNative(function(tag) { return createMockElement(tag); }, "createElement"),
    createElementNS: patchNative(function(ns, tag) { return createMockElement(tag); }, "createElementNS"),
    createTextNode: patchNative(function(txt) { return { nodeType: 3, nodeValue: String(txt) }; }, "createTextNode"),
    getElementById: patchNative(function(id) {
      if (!id) return null;
      if (!elementsById[id]) {
        const isBtn = String(id).toLowerCase().includes("button") || String(id).toLowerCase().includes("btn");
        const el = createMockElement(isBtn ? "button" : "div");
        el.id = id;
        elementsById[id] = el;
        document.body.appendChild(el);
      }
      return elementsById[id];
    }, "getElementById"),
    getElementsByTagName: patchNative(function(tag) {
      const t = (tag || "").toLowerCase();
      if (t === "script") return trackedScripts.length > 0 ? trackedScripts : [createMockElement("script")];
      if (t === "head") return [document.head];
      if (t === "body") return [document.body];
      if (t === "html") return [document.documentElement];
      return [];
    }, "getElementsByTagName"),
    getElementsByClassName: patchNative(function(cls) {
      const el = createMockElement("div");
      el.className = cls;
      document.body.appendChild(el);
      return [el];
    }, "getElementsByClassName"),
    getElementsByName: patchNative(function() { return []; }, "getElementsByName"),
    querySelector: patchNative(function(sel) {
      if (!sel) return null;
      if (sel.startsWith("#")) {
        return document.getElementById(sel.slice(1));
      }
      const el = createMockElement("div");
      document.body.appendChild(el);
      return el;
    }, "querySelector"),
    querySelectorAll: patchNative(function(sel) {
      const el = document.querySelector(sel);
      return el ? [el] : [];
    }, "querySelectorAll"),
    addEventListener: patchNative(addEventListener, "addEventListener"),
    removeEventListener: patchNative(removeEventListener, "removeEventListener"),
    dispatchEvent: patchNative(dispatchEvent, "dispatchEvent")
  };
  document.documentElement.appendChild(document.head);
  document.documentElement.appendChild(document.body);

  const CPT_ELEMENT_IDS = [
    "sec-if-cpt-container",
    "sec-bc-text-container",
    "sec-bc-tile-parent",
    "sec-bc-tile-container",
    "progress-button",
    "sec-cpr-overlay"
  ];
  CPT_ELEMENT_IDS.forEach(id => {
    document.getElementById(id);
  });

  Object.defineProperty(global, "document", { value: document, writable: true, configurable: true });
  global.window.document = document;

  // 8. Crypto and Audio Mocks
  const crypto = {
    getRandomValues: patchNative(function(arr) {
      for (let i = 0; i < arr.length; i++) arr[i] = Math.floor(Math.random() * 256);
      return arr;
    }, "getRandomValues"),
    subtle: {
      digest: patchNative(function(algo, data) {
        const buf = new ArrayBuffer(32);
        const view = new Uint8Array(buf);
        for (let i = 0; i < 32; i++) view[i] = (i * 17 + 5) % 256;
        return Promise.resolve(buf);
      }, "digest")
    }
  };
  Object.defineProperty(global, "crypto", { value: crypto, writable: true, configurable: true });

  function MockAudioBuffer() {
    this.length = 44100;
    this.sampleRate = 44100;
    this.numberOfChannels = 1;
    this.duration = 1.0;
    this.getChannelData = patchNative(function(c) {
      const data = new Float32Array(44100);
      const realSlice = [
        -0.10808049887418747, -0.39091169834136963, -0.005692684557288885, 0.3892313241958618,
        0.1189708486199379, -0.3545846939086914, -0.22215832769870758, 0.28990939259529114,
        0.30651888251304626, -0.20068730413913727, -0.3649080991744995, 0.09447670727968216,
        0.39241594076156616, 0.01972721517086029, -0.38671594858169556, -0.13228479027748108,
        0.34825482964515686, 0.2336597442626953, -0.28028473258018494, -0.3152626156806946
      ];
      for (let i = 0; i < data.length; i++) {
        data[i] = realSlice[i % realSlice.length];
      }
      return data;
    }, "getChannelData");
  }

  function MockAudioNode() {
    this.connect = patchNative(function(target) { return target; }, "connect");
    this.disconnect = patchNative(function() {}, "disconnect");
  }

  function MockOscillatorNode() {
    MockAudioNode.call(this);
    this.type = "sine";
    this.frequency = { value: 440, setValueAtTime: function() {} };
    this.start = patchNative(function() {}, "start");
    this.stop = patchNative(function() {}, "stop");
  }

  function MockDynamicsCompressorNode() {
    MockAudioNode.call(this);
    this.threshold = { value: -24 };
    this.knee = { value: 30 };
    this.ratio = { value: 12 };
    this.reduction = { value: 0 };
    this.attack = { value: 0.003 };
    this.release = { value: 0.25 };
  }

  function MockAudioContext() {
    this.destination = new MockAudioNode();
    this.createOscillator = patchNative(function() { return new MockOscillatorNode(); }, "createOscillator");
    this.createDynamicsCompressor = patchNative(function() { return new MockDynamicsCompressorNode(); }, "createDynamicsCompressor");
    this.createGain = patchNative(function() { return new MockAudioNode(); }, "createGain");
    this.createAnalyser = patchNative(function() {
      const node = new MockAudioNode();
      node.getFloatFrequencyData = patchNative(function(arr) {}, "getFloatFrequencyData");
      node.getByteFrequencyData = patchNative(function(arr) {}, "getByteFrequencyData");
      return node;
    }, "createAnalyser");
    this.createBufferSource = patchNative(function() {
      const node = new MockAudioNode();
      node.buffer = null;
      node.start = patchNative(function() {}, "start");
      return node;
    }, "createBufferSource");
    this.startRendering = patchNative(function() {
      return Promise.resolve(new MockAudioBuffer());
    }, "startRendering");
    this.resume = patchNative(function() { return Promise.resolve(); }, "resume");
    this.close = patchNative(function() { return Promise.resolve(); }, "close");
  }

  patchNative(MockAudioContext, "AudioContext");
  patchNative(MockAudioContext, "webkitAudioContext");
  patchNative(MockAudioContext, "OfflineAudioContext");

  global.AudioContext = MockAudioContext;
  global.webkitAudioContext = MockAudioContext;
  global.OfflineAudioContext = MockAudioContext;

  // 9. Performance & V8 Virtual JIT Clock Algorithm
  const startTime = Date.now() - 1500;
  let virtualNow = 118.4;
  let callCount = 0;
  let lastRealTime = Date.now();

  function virtualJITNow() {
    callCount++;
    const currentRealTime = Date.now();
    const realDelta = currentRealTime - lastRealTime;

    // V8 TurboFan warmup & micro-timing model:
    let microIncrement = 0.05 + (callCount % 5) * 0.02;
    if (callCount <= 12) {
      microIncrement += (12 - callCount) * 0.06;
    }

    if (realDelta > 0) {
      const scaledDelta = realDelta * 0.35;
      virtualNow += Math.max(microIncrement, scaledDelta);
      lastRealTime = currentRealTime;
    } else {
      virtualNow += microIncrement;
    }

    // Chrome quantizes performance.now to 100 microseconds (0.1ms)
    return Math.round(virtualNow * 10) / 10;
  }

  const performance = {
    timeOrigin: startTime,
    now: patchNative(virtualJITNow, "now"),
    timing: {
      navigationStart: startTime,
      unloadEventStart: 0,
      unloadEventEnd: 0,
      redirectStart: 0,
      redirectEnd: 0,
      fetchStart: startTime + 5,
      domainLookupStart: startTime + 10,
      domainLookupEnd: startTime + 20,
      connectStart: startTime + 20,
      connectEnd: startTime + 45,
      secureConnectionStart: startTime + 25,
      requestStart: startTime + 46,
      responseStart: startTime + 90,
      responseEnd: startTime + 110,
      domLoading: startTime + 115,
      domInteractive: startTime + 250,
      domContentLoadedEventStart: startTime + 260,
      domContentLoadedEventEnd: startTime + 270,
      domComplete: startTime + 400,
      loadEventStart: startTime + 410,
      loadEventEnd: startTime + 420
    },
    getEntriesByType: patchNative(function() { return []; }, "getEntriesByType"),
    getEntriesByName: patchNative(function() { return []; }, "getEntriesByName"),
    getEntries: patchNative(function() { return []; }, "getEntries"),
    mark: patchNative(function() {}, "mark"),
    measure: patchNative(function() {}, "measure"),
    clearMarks: patchNative(function() {}, "clearMarks"),
    clearMeasures: patchNative(function() {}, "clearMeasures")
  };
  Object.defineProperty(global, "performance", { value: performance, writable: true, configurable: true });

  // 10. Storage
  const storageMap = {};
  const storage = {
    getItem: patchNative(function(k) { return storageMap[k] || null; }, "getItem"),
    setItem: patchNative(function(k, v) { storageMap[k] = String(v); }, "setItem"),
    removeItem: patchNative(function(k) { delete storageMap[k]; }, "removeItem"),
    clear: patchNative(function() { Object.keys(storageMap).forEach(k => delete storageMap[k]); }, "clear"),
    key: patchNative(function(i) { return Object.keys(storageMap)[i] || null; }, "key"),
    get length() { return Object.keys(storageMap).length; }
  };
  Object.defineProperty(global, "localStorage", { value: storage, writable: true, configurable: true });
  Object.defineProperty(global, "sessionStorage", { value: storage, writable: true, configurable: true });

  // 11. Timer and Event Loop Helpers
  const timers = [];
  global.setTimeout = patchNative(function(fn, delay, ...args) {
    const id = timers.length + 1;
    timers.push({ id, fn, args, delay: delay || 0, type: "timeout" });
    return id;
  }, "setTimeout");

  global.setInterval = patchNative(function(fn, delay, ...args) {
    const id = timers.length + 1;
    timers.push({ id, fn, args, delay: delay || 0, type: "interval" });
    return id;
  }, "setInterval");

  global.clearTimeout = patchNative(function(id) {}, "clearTimeout");
  global.clearInterval = patchNative(function(id) {}, "clearInterval");
  global.requestAnimationFrame = patchNative(function(fn) { return global.setTimeout(fn, 16); }, "requestAnimationFrame");
  global.cancelAnimationFrame = patchNative(function(id) { global.clearTimeout(id); }, "cancelAnimationFrame");

  global.addEventListener = patchNative(addEventListener, "addEventListener");
  global.removeEventListener = patchNative(removeEventListener, "removeEventListener");
  global.dispatchEvent = patchNative(dispatchEvent, "dispatchEvent");

  // 12. Captured XHR & Fetch Interceptor
  global.__captured_sensor_data = null;
  global.__sensor_posts = [];

  function XMLHttpRequest() {
    this.method = "GET";
    this.url = "";
    this.headers = {};
    this.readyState = 0;
    this.status = 200;
    this.onreadystatechange = null;
    this.onload = null;
    this.onerror = null;

    this.open = patchNative(function(method, url, async) {
      this.method = method;
      this.url = url;
      this.readyState = 1;
    }, "open");

    this.setRequestHeader = patchNative(function(header, value) {
      this.headers[header] = value;
    }, "setRequestHeader");

    this.send = patchNative(function(body) {
      this.readyState = 4;
      this.status = 200;
      this.statusText = "OK";
      this.responseText = "{}";
      this.response = "{}";
      global.__captured_sensor_data = body;
      global.__sensor_posts.push({ url: this.url, method: this.method, headers: this.headers, body: body });
      if (typeof this.onreadystatechange === "function") {
        try { this.onreadystatechange(); } catch(e) {}
      }
      if (typeof this.onload === "function") {
        try { this.onload(); } catch(e) {}
      }
    }, "send");
  }
  patchNative(XMLHttpRequest, "XMLHttpRequest");
  global.XMLHttpRequest = XMLHttpRequest;

  // 13. Synthetic Human Interaction Simulation (Bézier Spline Physics)
  global.__simulateHumanInteractions = function() {
    // Generate natural human cursor trajectory between (120, 80) and (840, 520)
    const p0 = { x: 120, y: 80 };
    const p1 = { x: 310, y: 190 };
    const p2 = { x: 580, y: 440 };
    const p3 = { x: 840, y: 520 };

    const totalSteps = 24;
    let prevX = p0.x, prevY = p0.y;

    for (let i = 0; i <= totalSteps; i++) {
      const t = i / totalSteps;
      const u = 1 - t;
      // Cubic Bézier formula with micro-jitter
      const rawX = u*u*u*p0.x + 3*u*u*t*p1.x + 3*u*t*t*p2.x + t*t*t*p3.x;
      const rawY = u*u*u*p0.y + 3*u*u*t*p1.y + 3*u*t*t*p2.y + t*t*t*p3.y;
      const jitter = (i % 3 === 0) ? (i % 2 === 0 ? 1 : -1) : 0;

      const x = Math.round(rawX + jitter);
      const y = Math.round(rawY + jitter);
      const timeOffset = Math.round(50 + t * 480 + Math.sin(t * Math.PI) * 20);

      const evt = {
        type: "mousemove",
        clientX: x,
        clientY: y,
        pageX: x,
        pageY: y,
        screenX: x + 20,
        screenY: y + 85,
        movementX: x - prevX,
        movementY: y - prevY,
        buttons: 0,
        button: 0,
        timeStamp: startTime + timeOffset,
        target: document.body,
        isTrusted: true
      };
      prevX = x;
      prevY = y;
      dispatchEvent(evt);
    }

    // Natural click at target coordinate
    const clickTime = startTime + 560;
    dispatchEvent({ type: "mousedown", clientX: prevX, clientY: prevY, screenX: prevX + 20, screenY: prevY + 85, button: 0, buttons: 1, timeStamp: clickTime, target: document.body, isTrusted: true });
    dispatchEvent({ type: "mouseup", clientX: prevX, clientY: prevY, screenX: prevX + 20, screenY: prevY + 85, button: 0, buttons: 0, timeStamp: clickTime + 85, target: document.body, isTrusted: true });
    dispatchEvent({ type: "click", clientX: prevX, clientY: prevY, screenX: prevX + 20, screenY: prevY + 85, button: 0, buttons: 0, timeStamp: clickTime + 90, target: document.body, isTrusted: true });

    dispatchEvent({ type: "focus", target: window, isTrusted: true });
    dispatchEvent({ type: "scroll", target: window, isTrusted: true });
  };

  // 14. Step-by-step Event Loop Runner
  global.__drainEventLoop = function(maxSteps = 50) {
    let steps = 0;
    while (timers.length > 0 && steps < maxSteps) {
      steps++;
      const timer = timers.shift();
      try {
        if (typeof timer.fn === "function") {
          timer.fn.apply(global, timer.args || []);
        } else if (typeof timer.fn === "string") {
          eval(timer.fn);
        }
      } catch(e) {}
    }
  };

  // 15. Trusted Types Polyfill
  const trustedTypes = {
    createPolicy: patchNative(function(name, rules) {
      return {
        name: name,
        createScript: patchNative(function(s) { return rules && rules.createScript ? rules.createScript(s) : s; }, "createScript"),
        createScriptURL: patchNative(function(u) { return rules && rules.createScriptURL ? rules.createScriptURL(u) : u; }, "createScriptURL"),
        createHTML: patchNative(function(h) { return rules && rules.createHTML ? rules.createHTML(h) : h; }, "createHTML")
      };
    }, "createPolicy"),
    isScript: patchNative(function() { return true; }, "isScript"),
    isScriptURL: patchNative(function() { return true; }, "isScriptURL"),
    isHTML: patchNative(function() { return true; }, "isHTML"),
    emptyScript: "",
    emptyHTML: ""
  };
  Object.defineProperty(global, "trustedTypes", { value: trustedTypes, writable: true, configurable: true });

})(globalThis);
