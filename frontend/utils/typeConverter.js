export const decodeBase64 = base64 => {
    const binary = atob(base64);
    const decoded = new TextDecoder().decode(Uint8Array.from(binary, c => c.charCodeAt(0)));
    return decoded;
};