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
    let previousHash=window.location.hash;
    const onChange = () => {
      const event=new Event("admin:navigate", {cancelable:true});
      if (!window.dispatchEvent(event)) {
        window.history.replaceState(null,"",window.location.pathname+window.location.search+previousHash);
        return;
      }
      previousHash=window.location.hash;
      setRoute(currentRoute());
    };
    window.addEventListener("hashchange", onChange);
    return () => window.removeEventListener("hashchange", onChange);
  }, []);
  return route;
}

export function navigate(path) {
  window.location.hash = path;
}
