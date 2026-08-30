// Virtual Browser Environment Polyfill for QuickJS
(function(global) {
  "use strict";

  // 1. Establish window hierarchy
  global.window = global;
  global.self = global;
  global.top = global;
  global.parent = global;
  global.name = "";

  // Helper to make functions look like native functions
  function patchNative(fn, name) {
    if (!fn) return fn;
    try {
      Object.defineProperty(fn, "name", { value: name, configurable: true });
    } catch(e) {}
    try {
      fn.toString = function() { return "function " + name + "() { [native code] }"; };
      fn.toString.toString = function() { return "function toString() { [native code] }"; };
    } catch(e) {}
    return fn;
  }

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
    "URL", "URLSearchParams", "DOMParser", "XMLSerializer", "XPathEvaluator", "XPathResult",
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

  // 3. Location object
  const currentUrl = global.__TARGET_URL__ || "http://localhost/";
  let parsedUrl = {
    href: currentUrl,
    origin: "",
    protocol: "http:",
    host: "localhost",
    hostname: "localhost",
    port: "",
    pathname: "/",
    search: "",
    hash: ""
  };

  try {
    const match = currentUrl.match(/^(https?:)\/\/([^/:?#]+)(?::(\d+))?([^?#]*)(?:\?([^#]*))?(?:#(.*))?$/);
    if (match) {
      parsedUrl.protocol = match[1];
      parsedUrl.hostname = match[2];
      parsedUrl.port = match[3] || "";
      parsedUrl.host = parsedUrl.port ? `${parsedUrl.hostname}:${parsedUrl.port}` : parsedUrl.hostname;
      parsedUrl.origin = `${parsedUrl.protocol}//${parsedUrl.host}`;
      parsedUrl.pathname = match[4] || "/";
      parsedUrl.search = match[5] ? `?${match[5]}` : "";
      parsedUrl.hash = match[6] ? `#${match[6]}` : "";
    } else {
      parsedUrl.origin = `${parsedUrl.protocol}//${parsedUrl.host}`;
    }
  } catch(e) {}

  const location = {
    ...parsedUrl,
    assign: patchNative(function(url) {}, "assign"),
    replace: patchNative(function(url) {}, "replace"),
    reload: patchNative(function() {}, "reload"),
    toString: patchNative(function() { return this.href; }, "toString")
  };
  Object.defineProperty(global, "location", { value: location, writable: true, configurable: true });

  // 4. Navigator object
  const defaultUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36";
  const userAgent = global.__USER_AGENT__ || defaultUA;
  const platform = global.__PLATFORM__ || (userAgent.includes("Win") ? "Win32" : (userAgent.includes("Android") ? "Linux armv81" : (userAgent.includes("iPhone") || userAgent.includes("iPad") ? "iPhone" : "MacIntel")));
  const language = global.__LANGUAGE__ || "en-US";

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
    maxTouchPoints: userAgent.includes("Android") || userAgent.includes("iPhone") ? 5 : 0,
    onLine: true,
    doNotTrack: null,
    plugins: Object.freeze([
      { name: "PDF Viewer", filename: "internal-pdf-viewer", description: "Portable Document Format" },
      { name: "Chrome PDF Viewer", filename: "internal-pdf-viewer", description: "Portable Document Format" },
      { name: "Chromium PDF Viewer", filename: "internal-pdf-viewer", description: "Portable Document Format" },
      { name: "Microsoft Edge PDF Viewer", filename: "internal-pdf-viewer", description: "Portable Document Format" },
      { name: "WebKit built-in PDF", filename: "internal-pdf-viewer", description: "Portable Document Format" }
    ]),
    mimeTypes: Object.freeze([
      { type: "application/pdf", suffixes: "pdf", description: "Portable Document Format" },
      { type: "text/pdf", suffixes: "pdf", description: "Portable Document Format" }
    ]),
    connection: {
      effectiveType: "4g",
      rtt: 50,
      downlink: 10,
      saveData: false,
      addEventListener: patchNative(function() {}, "addEventListener")
    },
    permissions: {
      query: patchNative(function(desc) {
        return Promise.resolve({ state: "granted", onchange: null });
      }, "query")
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
  const screen = {
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

  // 6. DOM Element Factory
  const eventListeners = {};
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

  function createMockElement(tagName) {
    const tag = tagName.toLowerCase();
    const children = [];
    const attributes = {};
    const style = {};

    const el = {
      tagName: tagName.toUpperCase(),
      nodeName: tagName.toUpperCase(),
      nodeType: 1,
      style: style,
      children: children,
      childNodes: children,
      clientWidth: tag === "body" || tag === "html" ? 1920 : 300,
      clientHeight: tag === "body" || tag === "html" ? 1080 : 150,
      offsetWidth: 300,
      offsetHeight: 150,
      offsetLeft: 0,
      offsetTop: 0,
      id: "",
      className: "",
      setAttribute: patchNative(function(k, v) { attributes[k] = String(v); }, "setAttribute"),
      getAttribute: patchNative(function(k) { return attributes[k] || null; }, "getAttribute"),
      hasAttribute: patchNative(function(k) { return k in attributes; }, "hasAttribute"),
      removeAttribute: patchNative(function(k) { delete attributes[k]; }, "removeAttribute"),
      appendChild: patchNative(function(child) { children.push(child); return child; }, "appendChild"),
      removeChild: patchNative(function(child) {
        const idx = children.indexOf(child);
        if (idx !== -1) children.splice(idx, 1);
        return child;
      }, "removeChild"),
      insertBefore: patchNative(function(node) { children.push(node); return node; }, "insertBefore"),
      addEventListener: patchNative(addEventListener, "addEventListener"),
      removeEventListener: patchNative(removeEventListener, "removeEventListener"),
      dispatchEvent: patchNative(dispatchEvent, "dispatchEvent"),
      getBoundingClientRect: patchNative(function() {
        return { top: 0, left: 0, right: 300, bottom: 150, width: 300, height: 150, x: 0, y: 0 };
      }, "getBoundingClientRect"),
      getElementsByTagName: patchNative(function() { return []; }, "getElementsByTagName")
    };

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
              const len = (w || 16) * (h || 16) * 4;
              const data = new Uint8ClampedArray(len);
              for (let i = 0; i < len; i += 4) {
                data[i] = (i * 33) % 255;
                data[i + 1] = (i * 47) % 255;
                data[i + 2] = (i * 59) % 255;
                data[i + 3] = 255;
              }
              return { data: data, width: w || 16, height: h || 16 };
            }, "getImageData"),
            save: patchNative(function() {}, "save"),
            restore: patchNative(function() {}, "restore")
          };
        }
        if (type && type.includes("webgl")) {
          return {
            canvas: el,
            getParameter: patchNative(function(param) {
              if (param === 0x9245 || param === 37445) return "Google Inc. (Apple)";
              if (param === 0x9246 || param === 37446) return "ANGLE (Apple, Apple M1 Pro, OpenGL 4.1)";
              if (param === 7936) return "WebKit";
              if (param === 7937) return "WebKit WebGL";
              if (param === 7938) return "WebGL 1.0 (OpenGL ES 2.0 Chromium)";
              return 0;
            }, "getParameter"),
            getExtension: patchNative(function(ext) {
              if (ext === "WEBGL_debug_renderer_info") {
                return { UNMASKED_VENDOR_WEBGL: 37445, UNMASKED_RENDERER_WEBGL: 37446 };
              }
              return {};
            }, "getExtension"),
            getSupportedExtensions: patchNative(function() {
              return ["ANGLE_instanced_arrays", "EXT_blend_minmax", "EXT_texture_filter_anisotropic", "WEBGL_debug_renderer_info"];
            }, "getSupportedExtensions"),
            clearColor: patchNative(function() {}, "clearColor"),
            clear: patchNative(function() {}, "clear"),
            createBuffer: patchNative(function() { return {}; }, "createBuffer"),
            bindBuffer: patchNative(function() {}, "bindBuffer"),
            bufferData: patchNative(function() {}, "bufferData")
          };
        }
        return null;
      }, "getContext");

      el.toDataURL = patchNative(function() {
        return "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAMgAAABkCAYAAADDhn8LAAAFeklEQVR42u3dv2sUQRzH8f0x3iY5q4mFggpq";
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
    getElementById: patchNative(function(id) { return null; }, "getElementById"),
    getElementsByTagName: patchNative(function(tag) {
      const t = (tag || "").toLowerCase();
      if (t === "script") return [createMockElement("script")];
      if (t === "head") return [document.head];
      if (t === "body") return [document.body];
      if (t === "html") return [document.documentElement];
      return [];
    }, "getElementsByTagName"),
    getElementsByClassName: patchNative(function() { return []; }, "getElementsByClassName"),
    getElementsByName: patchNative(function() { return []; }, "getElementsByName"),
    querySelector: patchNative(function() { return null; }, "querySelector"),
    querySelectorAll: patchNative(function() { return []; }, "querySelectorAll"),
    addEventListener: patchNative(addEventListener, "addEventListener"),
    removeEventListener: patchNative(removeEventListener, "removeEventListener"),
    dispatchEvent: patchNative(dispatchEvent, "dispatchEvent")
  };
  document.documentElement.appendChild(document.head);
  document.documentElement.appendChild(document.body);
  Object.defineProperty(global, "document", { value: document, writable: true, configurable: true });

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
    this.getChannelData = patchNative(function(c) {
      const data = new Float32Array(44100);
      for (let i = 0; i < data.length; i++) data[i] = Math.sin(i * 0.01);
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

  // 9. Performance & Timers
  const startTime = Date.now() - 1500;
  const performance = {
    timeOrigin: startTime,
    now: patchNative(function() { return Date.now() - startTime; }, "now"),
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

  // 13. Synthetic Human Interaction Simulation
  global.__simulateHumanInteractions = function() {
    const points = [
      { x: 120, y: 80, t: 50 },
      { x: 210, y: 140, t: 120 },
      { x: 350, y: 260, t: 210 },
      { x: 500, y: 340, t: 330 },
      { x: 620, y: 410, t: 450 },
      { x: 710, y: 460, t: 560 }
    ];

    points.forEach(pt => {
      const evt = {
        type: "mousemove",
        clientX: pt.x,
        clientY: pt.y,
        pageX: pt.x,
        pageY: pt.y,
        screenX: pt.x + 20,
        screenY: pt.y + 100,
        timeStamp: startTime + pt.t,
        target: document.body,
        isTrusted: true
      };
      dispatchEvent(evt);
    });

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

})(globalThis);
