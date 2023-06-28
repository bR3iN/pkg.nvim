(local {: scan-dir
        : spawn!
        : nmap!
        : empty?
        : dir-exists?
        : starts-with?
        : git-repo?
        : all
        : any
        : contains?
        : table?} (require :pkg.utils))

(local {:tbl_keys keys :tbl_map map :tbl_filter filter} vim)
(local sort! table.sort)

;; Package directory
(local pkg-dir (.. vim.env.HOME :/.local/share/nvim/site/pack/pkgs/start))

;; Table mapping pending callbacks to the list of package names they depend on
(var pending-cbs [])

;; Table mapping package names to their `pkg-state`
(var pkg-states {})

;; Enum of the state a package in `pkg-states` can be in
(local pkg-state {:downloading 0 :downloaded 1})

(fn url? [str]
  (->> [:https :http :ssh :file]
       (map #(.. $1 "://"))
       (map #(starts-with? $1 str))
       (any)))

(fn rm-scheme [url]
  (let [(_ end) (string.find url "://")]
    (string.sub url (+ end 1))))

(fn pkg-name->dir-name [pkg-name]
  (let [pkg-name (if (url? pkg-name)
                     (rm-scheme pkg-name)
                     pkg-name)]
    (match (-> pkg-name
               (string.gsub "/" "_")
               (string.gsub "%." "_"))
      (dir-name _) dir-name)))

(fn pkg-name->url [pkg-name]
  (if (url? pkg-name)
      pkg-name
      (.. "https://github.com/" pkg-name)))

(fn dir->path [dir-name]
  (.. pkg-dir "/" dir-name))

(fn pkg-name->path [pkg-name]
  (-> pkg-name
      (pkg-name->dir-name)
      (dir->path)))

(fn ready-cbs [pkg-states pending-cbs]
  (let [finished? (fn [pkg-name]
                    (= (. pkg-states pkg-name) pkg-state.downloaded))]
    (icollect [cb pkg-names (pairs pending-cbs)]
      (if (all (map finished? pkg-names))
          cb))))

(fn dispatch-ready-cbs! []
  (each [_ cb (ipairs (ready-cbs pkg-states pending-cbs))]
    (tset pending-cbs cb nil)
    (cb)))

(fn rm-cbs-waiting-on! [pkg-name]
  (let [orphaned-cbs (icollect [cb pkgs-waiting (pairs pending-cbs)]
                       (if (contains? pkg-name pkgs-waiting)
                           cb))]
    (each [_ cb (ipairs orphaned-cbs)]
      (tset pending-cbs cb nil))))

(fn rm-and-report! [path]
  (spawn! :rm {:args [:-r path]}
          (fn [code]
            (if (= code 0)
                (print :Removed path)
                (print "Failed to remove" path)))))

(fn gen-helptags! [path]
  (let [doc-path (.. path :/doc)]
    (if (dir-exists? doc-path)
        (vim.cmd (.. ":helptags " path :/doc)))))

;; Fetch plugin and trigger callbacks that are waiting on it
(fn fetch-pkg! [pkg-name path]
  (let [url (pkg-name->url pkg-name)]
    (spawn! :git {:args [:clone url path] :env [:GIT_TERMINAL_PROMPT=0]}
            (fn [code]
              (if (= code 0)
                  (do
                    (print (.. "Installed " pkg-name))
                    (tset pkg-states pkg-name pkg-state.downloaded)
                    (gen-helptags! path)
                    (dispatch-ready-cbs!))
                  (do
                    (print (.. "Failed to install " pkg-name))
                    (tset pkg-states pkg-name nil)
                    (rm-cbs-waiting-on! pkg-name)))))))

(fn add! [pkg-names ?setup]
  (let [pkg-names (if (table? pkg-names)
                      pkg-names
                      [pkg-names])
        setup (or ?setup (fn []))]
    (var blocked false)
    (each [_ pkg-name (ipairs pkg-names)]
      (match (. pkg-states pkg-name)
        (pkg-state.downloaded) nil
        (pkg-state.downloading) (set blocked true)
        nil (let [path (pkg-name->path pkg-name)]
              ;; Plugin is not yet known, check if it already exists
              ;; and download it if not
              (if (dir-exists? path)
                  (tset pkg-states pkg-name pkg-state.downloaded)
                  (do
                    (set blocked true)
                    (tset pkg-states pkg-name pkg-state.downloading)
                    (fetch-pkg! pkg-name path))))))
    (if blocked
        ;; Some plugins are currently downloading, setup register callback
        (let [cb (fn []
                   (vim.cmd.packloadall)
                   (setup))]
          (tset pending-cbs cb pkg-names))
        ;; Plugins are already installed, setup synchronously
        (setup))))

(fn clean! []
  (let [valid-dir-names (->> pkg-states
                             (keys)
                             (map pkg-name->dir-name))
        rm? #(not (contains? $1 valid-dir-names))]
    (scan-dir pkg-dir
              (fn [filename filetype]
                (if (and (= filetype :directory) (rm? filename))
                    (rm-and-report! (.. pkg-dir "/" filename)))))))

(fn list! []
  (let [pkg-names (keys pkg-states)
        sep "\n  "]
    (sort! pkg-names)
    (print (.. "Installed plugins:" sep (table.concat pkg-names sep)))
    (vim.cmd :messages)))

(fn update! []
  (scan-dir pkg-dir
            (fn [fname ftype]
              (let [path (.. pkg-dir "/" fname)]
                (if (and (= ftype :directory) (git-repo? path))
                    (spawn! :git {:args [:pull] :cwd path}
                            (fn [code]
                              (if (= code 0)
                                  (gen-helptags! path)
                                  (vim.cmd.packloadall)))))))))

(fn checkout [pkg-name branch-or-tag]
  (let [path (pkg-name->path pkg-name)]
    (spawn! :git {:args [:checkout branch-or-tag] :cwd path}
            (fn [code]
              (if (= code 0)
                  (print "Successfully checked out" branch-or-tag)
                  (print "Failed to check out" branch-or-tag))))))

(fn init! []
  ;; Reset internal package list
  (set pkg-states {})
  (set pending-cbs {})
  ;; Create package directory if necessary
  (vim.fn.mkdir pkg-dir :p))

(nmap! :<Plug>PkgUpdate #(update!))
(nmap! :<Plug>PkgList #(list!))

{: add! :init init! :clean clean! : checkout}
