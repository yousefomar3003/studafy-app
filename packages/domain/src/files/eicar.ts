/**
 * The EICAR test string: the industry-standard *safe* malware test file. It
 * contains no actual malicious code; every antivirus engine flags it by
 * exact signature. FILE-051 detects it the same way, which is what makes the
 * "EICAR-equivalent safe test" of the Part 5B plan runnable without ever
 * holding a real sample.
 */
export const EICAR_SIGNATURE =
  "X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*";

const SIGNATURE_BYTES = Uint8Array.from(
  [...EICAR_SIGNATURE].map((char) => char.charCodeAt(0)),
);

/**
 * Byte-exact subsequence search. A dedicated scanner avoids allocating a
 * 25 MiB string copy: the first byte is compared cheaply and the full
 * signature only on a first-byte hit.
 */
export function containsBytes(
  haystack: Uint8Array,
  needle: Uint8Array,
): boolean {
  if (needle.length === 0) return true;
  if (haystack.length < needle.length) return false;
  const first = needle[0];
  const lastValidStart = haystack.length - needle.length;
  outer:
  for (let index = 0; index <= lastValidStart; index++) {
    if (haystack[index] !== first) continue;
    for (let offset = 1; offset < needle.length; offset++) {
      if (haystack[index + offset] !== needle[offset]) continue outer;
    }
    return true;
  }
  return false;
}

/** True when the EICAR test signature appears anywhere in the buffer. */
export function containsEicarSignature(bytes: Uint8Array): boolean {
  return containsBytes(bytes, SIGNATURE_BYTES);
}

/** ASCII text of a byte range, for logging-free diagnostics and pattern search. */
export function asciiOf(bytes: Uint8Array): string {
  let out = "";
  const chunk = 0x8000;
  for (let start = 0; start < bytes.length; start += chunk) {
    out += String.fromCharCode(...bytes.subarray(start, start + chunk));
  }
  return out;
}
