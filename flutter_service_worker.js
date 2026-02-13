'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {".git/COMMIT_EDITMSG": "f41ae48cff59c72e785dafd0f49797f2",
".git/config": "0f41ec73d9f54d76d60aacdebe0082cd",
".git/description": "a0a7c3fff21f2aea3cfa1d0316dd816c",
".git/HEAD": "cf7dd3ce51958c5f13fece957cc417fb",
".git/hooks/applypatch-msg.sample": "ce562e08d8098926a3862fc6e7905199",
".git/hooks/commit-msg.sample": "579a3c1e12a1e74a98169175fb913012",
".git/hooks/fsmonitor-watchman.sample": "a0b2633a2c8e97501610bd3f73da66fc",
".git/hooks/post-update.sample": "2b7ea5cee3c49ff53d41e00785eb974c",
".git/hooks/pre-applypatch.sample": "054f9ffb8bfe04a599751cc757226dda",
".git/hooks/pre-commit.sample": "5029bfab85b1c39281aa9697379ea444",
".git/hooks/pre-merge-commit.sample": "39cb268e2a85d436b9eb6f47614c3cbc",
".git/hooks/pre-push.sample": "2c642152299a94e05ea26eae11993b13",
".git/hooks/pre-rebase.sample": "56e45f2bcbc8226d2b4200f7c46371bf",
".git/hooks/pre-receive.sample": "2ad18ec82c20af7b5926ed9cea6aeedd",
".git/hooks/prepare-commit-msg.sample": "2b5c047bdb474555e1787db32b2d2fc5",
".git/hooks/push-to-checkout.sample": "c7ab00c7784efeadad3ae9b228d4b4db",
".git/hooks/sendemail-validate.sample": "4d67df3a8d5c98cb8565c07e42be0b04",
".git/hooks/update.sample": "647ae13c682f7827c22f5fc08a03674e",
".git/index": "28f98f73c4e594376afee81f110f066f",
".git/info/exclude": "036208b4a1ab4a235d75c181e685e5a3",
".git/logs/HEAD": "c369dc73a73df5edeb887d2d6b6307e4",
".git/logs/refs/heads/main": "36225cadce8814836f4aec9b65505100",
".git/logs/refs/remotes/origin/main": "61c54c35df59f7b23de900c4bf8ae479",
".git/objects/01/e986c0978b691a7ec41e4c1dacaf2c55a1f793": "754e7490f8ced7f22a2ea14bde3fd654",
".git/objects/08/27c17254fd3959af211aaf91a82d3b9a804c2f": "360dc8df65dabbf4e7f858711c46cc09",
".git/objects/14/f7856eebe62cb27d4bc52862956912fcd85bdb": "b4d4059e409bfbfe4e2347a1e42b550b",
".git/objects/18/c1d7201f43dc2e2bad2477a587047c5c3576df": "e718ac4189d4994b4cf374c3328cc4c6",
".git/objects/1a/42e515e6f7d41fa1d93b5644f7a91ae4d543cd": "2426d6057f175ab2656db0feee2e1de8",
".git/objects/1b/9fec3a2830b7be9e7a541eabe6d78b8b889608": "5cac5a42f2a447cf54250b7343069f0e",
".git/objects/1e/1c16fa587339c2b7704632cb5aa8e3d0e0440d": "5a63b7376e835d0932e0664563db8533",
".git/objects/2a/de2c094737500952eca62b5d837192cbb76dc7": "6a7eff134d57f6dabd3e288de6e89086",
".git/objects/31/6ba4b086eb8333e53b04fdfcf5be2230c68a28": "09902c9d2fa0f5fa7071dc35ff32c962",
".git/objects/32/45885b57a3bd3655fef6a499b073d4934848a9": "3b057552f890cb226cd886c0bc205fd1",
".git/objects/34/c3899e05b9293abbcba241be77bdadd8840606": "64da900a1e4fc44dad0dc94baadda522",
".git/objects/35/5eb268d6e25753597ca8ba1a354d23e1631068": "e13c077687c68f9fc5cdb49ce716c601",
".git/objects/3a/8cda5335b4b2a108123194b84df133bac91b23": "1636ee51263ed072c69e4e3b8d14f339",
".git/objects/41/fa90b5e3ce403f349989f618eecfe7655968ca": "0c2fd9de7b7a4ef1f2d4b06d4fbbc860",
".git/objects/46/4ab5882a2234c39b1a4dbad5feba0954478155": "2e52a767dc04391de7b4d0beb32e7fc4",
".git/objects/47/085c4dc63a73b3bec37b5d4a2d5e1d8d61604e": "e87efa132df543eae08b4880e967f499",
".git/objects/4c/ff0df71654135b0779ccfeeef506732dd05c92": "7670298fb8043a2ecfdb0b52ff8e184d",
".git/objects/50/3e300d6cb53915348c151f3a08864d25721608": "da8fb15b1b02ce76b23661b53bed1bc5",
".git/objects/51/03e757c71f2abfd2269054a790f775ec61ffa4": "d437b77e41df8fcc0c0e99f143adc093",
".git/objects/52/09f939788c75ba4a7ae82ca4c31698d7b644a2": "bbf53619be4869978446dacd350cd5b5",
".git/objects/53/171570ca26dd6b1d85c2a17774f627b6fddcde": "c4a9de1fdaf9caf62d416622ce1f7d0c",
".git/objects/53/3bd6d23e409d16e2edd28e703a7fb84691007c": "e72f0467b09a84a0edd4fb10dfb32096",
".git/objects/56/3f312ec5ad47cc74b9207d9f7087f5af8a878d": "901d229d93a996f02fdd97352a72ff40",
".git/objects/5a/ab7910cbe8f25e8aa5bffb15ba78dfc4bf8977": "bd44e789ef2e20622bc2aec0bfe1c2f6",
".git/objects/68/2c37f029beb595643a11b31eb0cff0e9c0890f": "dfaaad6f8d3ff572647a1cf6f8b2a9c8",
".git/objects/68/43fddc6aef172d5576ecce56160b1c73bc0f85": "2a91c358adf65703ab820ee54e7aff37",
".git/objects/6b/9862a1351012dc0f337c9ee5067ed3dbfbb439": "85896cd5fba127825eb58df13dfac82b",
".git/objects/6e/0f5c78daa6e7d2bfaa944de45f7b319f18afce": "bc25af15db109c833c9fbe88a166c192",
".git/objects/6e/fb86f892d7a6bd288ec9b3af1f54e892aaf99e": "366b32fb0acd1ae6371a77a2d0ed40f7",
".git/objects/6f/7661bc79baa113f478e9a717e0c4959a3f3d27": "985be3a6935e9d31febd5205a9e04c4e",
".git/objects/70/5a4f1ce244d5141b9e592536e2c52ffeb8aa6a": "59d4f39236b93fdcdc0f7ad634a3fe8e",
".git/objects/72/7defc2f6fb7606daf0ce91542049d4078793ba": "420ae7deb9c5067acd863956f9d4dcda",
".git/objects/7c/3463b788d022128d17b29072564326f1fd8819": "37fee507a59e935fc85169a822943ba2",
".git/objects/85/63aed2175379d2e75ec05ec0373a302730b6ad": "997f96db42b2dde7c208b10d023a5a8e",
".git/objects/86/3bdb68e26bd4598a83a78d9c08b18a3d9a1611": "9cb8821e92cdb8e5ed68f8132bb8eb7f",
".git/objects/86/84c64ea04c9b76d0b619aac7f0b5c816a3121c": "fd87763e22da1397dfa5bf1d7dd1085a",
".git/objects/88/b30f810ed711a02081c9898160842ed6697848": "3b57cf00db787b3a72aa521c804acfab",
".git/objects/88/cfd48dff1169879ba46840804b412fe02fefd6": "e42aaae6a4cbfbc9f6326f1fa9e3380c",
".git/objects/8a/aa46ac1ae21512746f852a42ba87e4165dfdd1": "1d8820d345e38b30de033aa4b5a23e7b",
".git/objects/8e/21753cdb204192a414b235db41da6a8446c8b4": "1e467e19cabb5d3d38b8fe200c37479e",
".git/objects/90/353d20aa1d217d9a46f4bc571a69b70ee9257f": "8ee7fc1f0b43824d4ae4685b29f2266e",
".git/objects/93/b363f37b4951e6c5b9e1932ed169c9928b1e90": "c8d74fb3083c0dc39be8cff78a1d4dd5",
".git/objects/96/e46e8daccee0e72f0a2f9d096e499aea4c17f0": "f570c7d8e06227eddd5dd0964dcbebfe",
".git/objects/a3/3e525f84657979a4dd0f59130e69458375a973": "466cde03fed40564734242a7634b46ad",
".git/objects/a7/3f4b23dde68ce5a05ce4c658ccd690c7f707ec": "ee275830276a88bac752feff80ed6470",
".git/objects/aa/163c6312de4ae2cf35480ae03a831989256b61": "f54fb6f11389448e2ee9c5e0d030efc8",
".git/objects/ad/ced61befd6b9d30829511317b07b72e66918a1": "37e7fcca73f0b6930673b256fac467ae",
".git/objects/af/ce79faa19babdb10d0a5b7a04e59cbe013f17f": "565bc10c77c8b0fc3a1c66cb63949fca",
".git/objects/b0/22125f5e7a8cb5f736763fc655a78547ca8e99": "505f868157a34b1a9bea197e7bfdd80d",
".git/objects/b2/d2901aee2f648ea0d6997068d81636eb9cc94d": "6ef71f95ae9026034321b4494292e528",
".git/objects/b7/49bfef07473333cf1dd31e9eed89862a5d52aa": "36b4020dca303986cad10924774fb5dc",
".git/objects/b9/2a0d854da9a8f73216c4a0ef07a0f0a44e4373": "f62d1eb7f51165e2a6d2ef1921f976f3",
".git/objects/b9/3e39bd49dfaf9e225bb598cd9644f833badd9a": "666b0d595ebbcc37f0c7b61220c18864",
".git/objects/bf/bf7a62160e73b4eca269f2d31b2bd0157522e5": "816489089ce9ef8ea88ebddb63866249",
".git/objects/c2/7dcd64cef6f6231e7c43c6d591f11fb3b72c0c": "314aede42ef5c1b830ec05f37fc5cf40",
".git/objects/c3/f475ee137aec458e7e1e65a559536bac0aea33": "702bdd7a0c501b6dab71908ab4f29680",
".git/objects/c8/3af99da428c63c1f82efdcd11c8d5297bddb04": "144ef6d9a8ff9a753d6e3b9573d5242f",
".git/objects/cd/4b6bba941d9aca68f5e3dca412d3bb53038813": "8e0b4ff6c14d282f91d158b390025f65",
".git/objects/d1/ca54f3d6995459fcf1d0fdc6bc895d2c46c4ce": "0e8ed2a09211a2a60d5f10ff00ad92cd",
".git/objects/d4/3532a2348cc9c26053ddb5802f0e5d4b8abc05": "3dad9b209346b1723bb2cc68e7e42a44",
".git/objects/d4/f362449b6a4ea58bbd2bf9e847c8e10a406cfa": "fd86895429be4964387bb0e3ffe627f6",
".git/objects/d6/9c56691fbdb0b7efa65097c7cc1edac12a6d3e": "868ce37a3a78b0606713733248a2f579",
".git/objects/d7/7cfefdbe249b8bf90ce8244ed8fc1732fe8f73": "9c0876641083076714600718b0dab097",
".git/objects/d9/5b1d3499b3b3d3989fa2a461151ba2abd92a07": "a072a09ac2efe43c8d49b7356317e52e",
".git/objects/dd/8e066f4f9634ac07ca6fa2b941fff4edc5e213": "c48a9cfd37d2bce5034f7b9e6b1057da",
".git/objects/e7/3759e906a5e97d7d19f32aec8f2d14d9921ba3": "29f576dba1719c3085b41a9d6e6b9fc0",
".git/objects/e9/94225c71c957162e2dcc06abe8295e482f93a2": "2eed33506ed70a5848a0b06f5b754f2c",
".git/objects/eb/9b4d76e525556d5d89141648c724331630325d": "37c0954235cbe27c4d93e74fe9a578ef",
".git/objects/f3/3e0726c3581f96c51f862cf61120af36599a32": "afcaefd94c5f13d3da610e0defa27e50",
".git/objects/f5/72b90ef57ee79b82dd846c6871359a7cb10404": "e68f5265f0bb82d792ff536dcb99d803",
".git/objects/f5/fcc1a83c6a7acd30df0ec7f55dbac934399610": "24c6c88b67e34b1c56c7ec4aa14aaf46",
".git/objects/f6/e6c75d6f1151eeb165a90f04b4d99effa41e83": "95ea83d65d44e4c524c6d51286406ac8",
".git/objects/fb/e72a5f53dd77ab1b6091bfb5a30d5dfe117dcf": "4bb73f0c90194ae3954f8f3126d533b6",
".git/objects/fc/eef365e464cf58029f959fef44073a61c824a3": "a03191ff429a770f90ba730c4e9e2dcb",
".git/objects/fd/05cfbc927a4fedcbe4d6d4b62e2c1ed8918f26": "5675c69555d005a1a244cc8ba90a402c",
".git/objects/fd/c05229e34605f95f79628dba83ebff0334f266": "c2b18f9cb08a1b2b2c1b923d9cd53686",
".git/refs/heads/main": "a6f81c347d024a49761a76e7fc752fdd",
".git/refs/remotes/origin/main": "a6f81c347d024a49761a76e7fc752fdd",
"assets/AssetManifest.bin": "26a0050b29093aa061492dec3b44f70a",
"assets/AssetManifest.bin.json": "410a37af9b23a13efa1ba2712f8c4d9f",
"assets/assets/images/julie.png": "743a998c8c8745799c910ef4af9d989f",
"assets/assets/images/liuan.gif": "5f160b8a0f2a1b9651bc362eb8c31127",
"assets/assets/images/novice.png": "62785e90fac143b186cade656d0341fc",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "2faf36675b4294997753384fa7c1b951",
"assets/NOTICES": "e24fe62e2ede4e872f5a4f194e434fe0",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4",
"canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"flutter_bootstrap.js": "8c71ce9711bbae6fefe37154e2bceaea",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "27a443eca650a76e8e4b7bf1a03e0dc7",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "6356416c494a3186d76e51831328c824",
"/": "6356416c494a3186d76e51831328c824",
"main.dart.js": "47bd1e66aa826aef436bf1929dcb35ed",
"manifest.json": "a7ae848fd53b2fb588e6187169d96879",
"version.json": "15235b5108d6a877ef74fe3317a96bf7"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
