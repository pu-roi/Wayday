export interface QualifiedRelease {
  qualified: true;
  version: string;
  publishedAt: string;
  apkUrl: string;
  notesUrl: string;
  sizeBytes: number;
  sha256: string;
  compatibility: string;
}

const repository = "https://github.com/pu-roi/Wayday";
export const feedbackUrl = `${repository}/issues`;
export const releasesUrl = `${repository}/releases`;

export function qualifiedRelease(input: unknown): QualifiedRelease | null {
  if (!input || typeof input !== "object") return null;
  const r = input as Record<string, unknown>;
  const text = (v: unknown): v is string =>
    typeof v === "string" && v.trim().length > 0;
  const releaseLink = (value: unknown, prefix: string) => {
    if (!text(value) || !value.startsWith(`${repository}/releases/${prefix}/`))
      return false;
    try {
      const url = new URL(value);
      return (
        !url.search &&
        !url.hash &&
        !url.username &&
        !url.password &&
        url.origin === "https://github.com" &&
        !url.pathname.includes("..") &&
        (prefix !== "download" || url.pathname.endsWith(".apk"))
      );
    } catch {
      return false;
    }
  };
  if (
    r.qualified !== true ||
    !text(r.version) ||
    !text(r.compatibility) ||
    !text(r.publishedAt) ||
    !/^\d{4}-\d{2}-\d{2}T/.test(r.publishedAt) ||
    !Number.isFinite(Date.parse(r.publishedAt)) ||
    !Number.isSafeInteger(r.sizeBytes) ||
    (r.sizeBytes as number) <= 0 ||
    !text(r.sha256) ||
    !/^[a-f0-9]{64}$/.test(r.sha256) ||
    !releaseLink(r.apkUrl, "download") ||
    !releaseLink(r.notesUrl, "tag")
  )
    return null;
  return {
    qualified: true,
    version: r.version,
    compatibility: r.compatibility,
    publishedAt: r.publishedAt,
    apkUrl: r.apkUrl as string,
    notesUrl: r.notesUrl as string,
    sizeBytes: r.sizeBytes as number,
    sha256: r.sha256,
  };
}
