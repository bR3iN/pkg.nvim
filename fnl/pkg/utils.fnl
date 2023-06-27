(local uv vim.loop)

(local M {})

(fn M.dir-exists? [path]
  (-> path
      vim.fn.isdirectory
      (not= 0)))

(fn M.git-repo? [path]
  (-> path
      (.. :/.git)
      M.dir-exists?))

(fn M.all [bools]
  (accumulate [res true _ bool (ipairs bools) &until (not res)]
    bool))

(fn M.any [bools]
  (accumulate [res false _ bool (ipairs bools) &until res]
    bool))

(fn M.contains? [target vals]
  (vim.tbl_contains vals target))

(fn M.empty? [tbl]
  (= 0 (length tbl)))

(fn M.table? [val]
  (= (type val) :table))

(fn M.nmap! [keys cb]
  (vim.keymap.set :n keys cb {:noremap true :silent true}))

(fn M.starts-with? [prefix str]
  (= (string.sub str 1 (length prefix)) prefix))

(fn parse-cmd [[file & args]]
  (values file args))

(fn M.spawn [cmd cb ?opts]
  (let [(file args) (parse-cmd cmd)
        opts (doto (or ?opts {})
               (tset :args args))]
    (uv.spawn file opts (vim.schedule_wrap cb))))

;; Hide callbacks and error handling in low-level luvit calls.
;; `args` are the output paramters of the call minus the error
;; value as well the call itself minus the callback parameter.
;; Example: `(uv! [dir (uv.fs_opendir path)]
;;             (use dir))`
;; translates to
;;          `(uv.fs_opendir
;;             path
;;             (fn [err dir]
;;               (assert (not err) err)
;;               (use dir)))`
(macro uv! [args ...]
  ;; Split off the luvit call
  (let [call (table.remove args) ;; Create the callback
        cb `(fn ,(doto args
                   ;; Insert error paramter into function signature
                   (table.insert 1 `err#))
              (do
                ;; Add error handling
                (assert (not err#) err#)
                ;; Actual callback body
                ,...))]
    ;; Insert callback into libuv call
    (doto call
      (table.insert cb))))

(fn M.scan-dir [path cb]
  (let [wrapped-cb (vim.schedule_wrap (fn [entry]
                                        (cb entry.name entry.type)))]
    (uv! [dir (uv.fs_opendir path)]
         (fn iter []
           (uv! [entries (dir:readdir)]
                (if entries
                    (do
                      (vim.tbl_map wrapped-cb entries)
                      (iter))
                    (dir:closedir)))) (iter))))

M
