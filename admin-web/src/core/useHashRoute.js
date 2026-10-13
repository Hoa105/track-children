import { useEffect, useState } from "react";

// Router tối giản theo hash (#/users, #/invite?token=...) — đủ cho admin
// một trang, không cần thêm thư viện.
function currentRoute() {
  const [path, search = ""] = (window.location.hash.replace(/^#/, "") || "/").split("?");
  return { path: path || "/", params: new URLSearchParams(search) };
}

export function useHashRoute() {
  const [route, setRoute] = useState(currentRoute);
  useEffect(() => {
    const onChange = () => setRoute(currentRoute());
    window.addEventListener("hashchange", onChange);
    return () => window.removeEventListener("hashchange", onChange);
  }, []);
  return route;
}

export function navigate(path) {
  window.location.hash = path;
}
