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
          const gl = {
            canvas: el,
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
            MAX_TEXTURE_SIZE: 3379,
            MAX_VIEWPORT_DIMS: 3386,
            VENDOR: 7936,
            RENDERER: 7937,
            VERSION: 7938,
            SHADING_LANGUAGE_VERSION: 35724,

            getParameter: patchNative(function(param) {
              if (param === 0x9245 || param === 37445) return "Google Inc. (Apple)";
              if (param === 0x9246 || param === 37446) return "ANGLE (Apple, Apple M1 Pro, OpenGL 4.1 Metal - 83.1)";
              if (param === 7936) return "WebKit";
              if (param === 7937) return "WebKit WebGL";
              if (param === 7938) return "WebGL 1.0 (OpenGL ES 2.0 Chromium)";
              if (param === 35724) return "WebGL GLSL ES 1.0 (OpenGL ES GLSL ES 1.0 Chromium)";
              if (param === 3379) return 16384;
              if (param === 3386) return new Int32Array([16384, 16384]);
              if (param === 34076) return 16384;
              if (param === 34921) return 16;
              if (param === 34930) return 16;
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
                "ANGLE_instanced_arrays", "EXT_blend_minmax", "EXT_color_buffer_half_float",
                "EXT_disjoint_timer_query", "EXT_float_blend", "EXT_frag_depth",
                "EXT_shader_texture_lod", "EXT_texture_compression_bptc", "EXT_texture_compression_rgtc",
                "EXT_texture_filter_anisotropic", "WEBGL_color_buffer_float", "WEBGL_compressed_texture_s3tc",
                "WEBGL_debug_renderer_info", "WEBGL_debug_shaders", "WEBGL_depth_texture",
                "WEBGL_draw_buffers", "WEBGL_lose_context", "WEBGL_multi_draw"
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
            clearColor: patchNative(function(r, g, b, a) {}, "clearColor"),
            clear: patchNative(function(mask) {}, "clear"),
            drawArrays: patchNative(function(mode, first, count) {}, "drawArrays"),
            drawElements: patchNative(function() {}, "drawElements"),
            createTexture: patchNative(function() { return {}; }, "createTexture"),
            bindTexture: patchNative(function() {}, "bindTexture"),
            texParameteri: patchNative(function() {}, "texParameteri"),
            texImage2D: patchNative(function() {}, "texImage2D"),
            readPixels: patchNative(function(x, y, w, h, format, type, pixels) {
              if (pixels && pixels.length) {
                for (let i = 0; i < pixels.length; i += 4) {
                  pixels[i] = (i * 17 + 128) % 256;
                  pixels[i + 1] = (i * 31 + 64) % 256;
                  pixels[i + 2] = (i * 47 + 200) % 256;
                  pixels[i + 3] = 255;
                }
              }
            }, "readPixels")
          };
          return gl;
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
