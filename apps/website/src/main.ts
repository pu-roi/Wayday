import Lenis from "lenis";
import { gsap } from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import "lenis/dist/lenis.css";
import "./style.css";
import "./responsive.css";
import { qualifiedRelease } from "./release";
import { createScrollScenes } from "./motion";
declare const __WAYDAY_RELEASE_DATA__: unknown;

const release = qualifiedRelease(__WAYDAY_RELEASE_DATA__);
if (release) {
  const panel = document.querySelector<HTMLElement>("#release-panel")!;
  const download = document.createElement("a");
  download.className = "button";
  download.href = release.apkUrl;
  download.textContent = "Download Android app (.apk)";
  panel.replaceChildren(download);
  document.querySelector(".download-status")!.textContent =
    "Public development release";
  const metadata = document.createElement("p");
  metadata.className = "release-meta";
  metadata.textContent = `${release.version} · ${new Date(release.publishedAt).toLocaleDateString("en-PH", { timeZone: "Asia/Manila", year: "numeric", month: "short", day: "numeric" })} · ${(release.sizeBytes / 1048576).toFixed(1)} MB`;
  panel.append(metadata);
  const compatibility = document.createElement("p");
  compatibility.textContent = release.compatibility;
  panel.append(compatibility);
  const notes = document.createElement("a");
  notes.href = release.notesUrl;
  notes.textContent = "Read release notes";
  panel.append(notes);
  const details = document.createElement("details");
  const summary = document.createElement("summary");
  summary.textContent = "SHA-256 checksum";
  const checksum = document.createElement("code");
  checksum.textContent = release.sha256;
  details.append(summary, checksum);
  panel.append(details);
  document.querySelector("#faq details p")!.textContent =
    "A qualified Android development release is available in the Download section. Wayday remains under development and is not currently offered through Google Play.";
  document.querySelector("#availability-summary")!.textContent =
    "A development release is available for Android. Review the release compatibility information below before installing.";
  document.querySelector("#download-intro")!.textContent =
    "Download the current Android development release.";
  document.querySelector(".install-guide h3")!.textContent =
    "How to install Wayday";
}

const toggle = document.querySelector<HTMLButtonElement>(".menu-toggle")!;
const nav = document.querySelector<HTMLElement>("#main-nav")!;
function closeMenu(restoreFocus = false) {
  toggle.setAttribute("aria-expanded", "false");
  nav.classList.remove("is-open");
  if (restoreFocus) toggle.focus();
}
toggle.addEventListener("click", () => {
  const open = toggle.getAttribute("aria-expanded") !== "true";
  toggle.setAttribute("aria-expanded", String(open));
  nav.classList.toggle("is-open", open);
});
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape" && toggle.getAttribute("aria-expanded") === "true")
    closeMenu(true);
});
document.addEventListener("click", (event) => {
  if (!(event.target as Element).closest(".site-header")) closeMenu();
});
const desktop = matchMedia("(min-width: 961px)");
desktop.addEventListener("change", () => closeMenu());

gsap.registerPlugin(ScrollTrigger);
const reducedMotion = matchMedia("(prefers-reduced-motion: reduce)");
let lenis: Lenis | undefined;
let cleanupMotion: (() => void) | undefined;
function configureMotion() {
  cleanupMotion?.();
  cleanupMotion = undefined;
  lenis = undefined;
  if (reducedMotion.matches) return;
  const scrolling = new Lenis({
    autoRaf: false,
    smoothWheel: true,
    syncTouch: false,
  });
  lenis = scrolling;
  scrolling.on("scroll", ScrollTrigger.update);
  const tick = (seconds: number) => scrolling.raf(seconds * 1000);
  gsap.ticker.add(tick);
  const clearScenes = createScrollScenes();
  cleanupMotion = () => {
    clearScenes();
    gsap.ticker.remove(tick);
    scrolling.destroy();
  };
}
configureMotion();
reducedMotion.addEventListener("change", () => {
  const marker = [
    ...document.querySelectorAll<HTMLElement>("main section[id], main h2[id]"),
  ].find((element) => {
    const top = element.getBoundingClientRect().top;
    return top >= 0 && top < innerHeight;
  });
  const before = marker?.getBoundingClientRect().top;
  configureMotion();
  ScrollTrigger.refresh();
  if (marker && before !== undefined) {
    window.scrollTo({
      top: window.scrollY + marker.getBoundingClientRect().top - before,
      behavior: "instant",
    });
  }
});

function moveToHash(hash: string, immediate: boolean, focus: boolean) {
  let target: HTMLElement | null = null;
  try {
    target = document.getElementById(decodeURIComponent(hash.slice(1)));
  } catch {
    return;
  }
  if (!target) return;
  const header =
    document.querySelector<HTMLElement>(".site-header")!.offsetHeight;
  const offset = header + 20;
  // A numeric destination avoids applying CSS anchor offsets a second time in Lenis.
  const destination = target.getBoundingClientRect().top + window.scrollY - offset;
  if (lenis)
    lenis.scrollTo(destination, { immediate, duration: 0.9 });
  else
    window.scrollTo({
      top: destination,
      behavior: "instant",
    });
  if (focus) {
    if (!target.hasAttribute("tabindex")) target.setAttribute("tabindex", "-1");
    target.focus({ preventScroll: true });
  }
}
document.addEventListener("click", (event) => {
  const mouse = event as MouseEvent;
  if (
    mouse.ctrlKey ||
    mouse.metaKey ||
    mouse.shiftKey ||
    mouse.altKey ||
    mouse.button !== 0
  )
    return;
  const link = (event.target as Element).closest<HTMLAnchorElement>(
    'a[href^="#"]',
  );
  if (!link || link.hash.length < 2) return;
  try {
    if (!document.getElementById(decodeURIComponent(link.hash.slice(1))))
      return;
  } catch {
    return;
  }
  event.preventDefault();
  closeMenu();
  if (location.hash !== link.hash) history.pushState(null, "", link.hash);
  moveToHash(link.hash, reducedMotion.matches, true);
});
const restore = () => moveToHash(location.hash || "#top", true, false);
window.addEventListener("popstate", restore);
window.addEventListener("hashchange", restore);
void document.fonts.ready.then(() => {
  if (location.hash) restore();
  ScrollTrigger.refresh();
});
const back = document.querySelector<HTMLAnchorElement>(".back-to-top")!;
const observer = new IntersectionObserver(
  ([entry]) => {
    back.hidden = entry.isIntersecting || entry.boundingClientRect.top >= 0;
  },
  { threshold: 0 },
);
observer.observe(document.querySelector("#top")!);
window.addEventListener("pagehide", () => {
  cleanupMotion?.();
  cleanupMotion = undefined;
  lenis = undefined;
  observer.disconnect();
});
window.addEventListener("pageshow", (event) => {
  if (event.persisted) {
    configureMotion();
    observer.observe(document.querySelector("#top")!);
    restore();
  }
});
