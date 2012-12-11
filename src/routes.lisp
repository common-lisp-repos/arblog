;;;; routes.lisp

(in-package #:arblog)

(defun url-with-skip (url skip)
  (let ((parsed-url (puri:parse-uri url)))
    (setf (puri:uri-query parsed-url)
          (format nil "skip=~A" skip))
    (puri:render-uri parsed-url nil)))

(defun navigation (url skip total-count)
  (list :older (if (< (+ skip *posts-on-page*) total-count)
                   (url-with-skip url
                                  (+ skip *posts-on-page*)))
        :newer (cond
                 ((= skip 0) nil)
                 ((> (- skip *posts-on-page*) 0)
                  (url-with-skip url (- skip *posts-on-page*)))
                 (t url))))

;;;; main page

(restas:define-route entry ("")
  (let ((skip (or (ignore-errors (parse-integer (hunchentoot:get-parameter "skip"))) 0)))
    (list :list-posts-page
          :navigation (navigation (restas:genurl 'entry)
                                  skip
                                  (st.count-posts))
          :posts (st.list-recent-posts skip *posts-on-page*))))

;;;; One post

(restas:define-route one-post (":year/:month/:day/:title"
                               :parse-vars (list :year #'parse-integer
                                                 :month #'parse-integer
                                                 :day #'parse-integer))
  (list :one-post-page
        :post (st.find-single-post year month day title)))

(restas:define-route post-permalink ("permalink/posts/:id")
  (let* ((info (st.get-single-post id :fields '("published" "title")))
         (title (gethash "title" info))
         (published (gethash "published" info)))
    (restas:redirect 'one-post
                     :year (local-time:timestamp-year published)
                     :month (local-time:timestamp-month published)
                     :day (local-time:timestamp-day published)
                     :title title)))

;;;; archive
  
(restas:define-route archive-for-year (":year/"
                                        :parse-vars (list :year #'parse-integer))
  (let* ((min (local-time:encode-timestamp 0 0 0 0 1 1 year))
         (max (local-time:adjust-timestamp min (offset :year 1)))
         (posts (st.list-archive-posts min max '("published")))
         (months (make-hash-table)))
    (dolist (post posts)
      (setf (gethash (local-time:timestamp-month (gethash "published" post)) months)
            1))
    (list :archive-for-year
          :year year
          :months (sort (iter (for (month x) in-hashtable months)
                              (collect month))
                        #'<))))
    
(restas:define-route archive-for-month (":year/:month/"
                                        :parse-vars (list :year #'parse-integer
                                                          :month #'parse-integer))
  (let* ((min (local-time:encode-timestamp 0 0 0 0 1 month year))
         (max (local-time:adjust-timestamp min (offset :month 1))))
    (list :archive-for-month
          :year year
          :month month
          :posts (st.list-archive-posts min max))))

(restas:define-route archive-for-day (":year/:month/:day/"
                                        :parse-vars (list :year #'parse-integer
                                                          :month #'parse-integer
                                                          :day #'parse-integer))
  (let* ((min (local-time:encode-timestamp 0 0 0 0 day month year))
         (max (local-time:adjust-timestamp min (offset :day 1))))
    (list :archive-for-day
          :year year
          :month month
          :day day
          :posts (st.list-archive-posts min max))))

;;;; Tags

(restas:define-route all-tags ("tags/")
  (list :tags-page
        :tags (st.all-tags)))
                 
(restas:define-route posts-with-tag ("tags/:tag")
  (let ((skip (or (ignore-errors (parse-integer (hunchentoot:get-parameter "skip"))) 0)))  
    (list :posts-with-tag-page
          :tag tag
          :navigation (navigation (restas:genurl 'posts-with-tag :tag tag)
                                  skip
                                  (st.count-posts tag))
          :posts (st.list-recent-posts skip
                                    *posts-on-page*
                                    :tag tag))))

;;;; Feeds

(restas:define-route posts-feed ("feeds/atom"
                                 :content-type "application/atom+xml")
  (list :atom-feed
        :name "archimag"
        :href-atom (restas:gen-full-url 'posts-feed)
        :href-html (restas:gen-full-url 'entry)
        :posts (st.list-recent-posts 0 50)))

(restas:define-route posts-with-tag-feed ("feeds/atom/tag/:tag"
                                          :content-type "application/atom+xml")
  (list :atom-feed
        :name (format nil "archimag blog posts with tag \"~A\"" tag)
        :href-atom (restas:gen-full-url 'posts-feed)
        :href-html (restas:gen-full-url 'entry)
        :posts (st.list-recent-posts 0 50 :tag tag)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Admin
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun check-admin-rights ()
  (multiple-value-bind (user password) (hunchentoot:authorization)
    (or (st.check-admin user password)
        (hunchentoot:require-authorization))))

(defun form-action-p (method)
  (alexandria:named-lambda required-form-action ()
    (hunchentoot:post-parameter method)))

(defun post-parameter-tags ()
  (iter (for tag in (split-sequence:split-sequence #\, (hunchentoot:post-parameter "tags")))
        (collect (string-trim #(#\Space #\Tab) tag))))

(defun preview-post ()
  (list :admin-preview-post-page
        :title (hunchentoot:post-parameter "title")
        :content-rst (hunchentoot:post-parameter "content")
        :tags (post-parameter-tags)))

;; main admin page

(restas:define-route admin-entry ("admin/")
  (check-admin-rights)
  (let ((skip (or (ignore-errors (parse-integer (hunchentoot:get-parameter "skip"))) 0))
        (*posts-on-page* 25))
    (list :admin-posts-page
          :navigation (navigation (restas:genurl 'admin-entry)
                                  skip
                                  (st.count-posts))
          :posts (st.list-recent-posts skip *posts-on-page* :fields '("title" "published")))))

;; create post

(restas:define-route admin-create-post ("admin/create-post")
  (check-admin-rights)
  (list :admin-create-post-page))

(restas:define-route admin-cancel-create-post ("admin/create-post"
                                               :method :post
                                               :requirement (form-action-p "cancel"))
  (check-admin-rights)
  (restas:redirect 'admin-entry))

(restas:define-route admin-preview-create-post ("admin/create-post"
                                                :method :post
                                                :requirement (form-action-p "preview"))
  (check-admin-rights)
  (preview-post))

(restas:define-route admin-save-create-post ("admin/create-post"
                                             :method :post
                                             :requirement (form-action-p "save"))
  (check-admin-rights)
  (let* ((content-rst (hunchentoot:post-parameter "content"))
        (id (st.insert-post (hunchentoot:post-parameter "title")
                            (post-parameter-tags)
                            (render-arblog-markup content-rst)
                            :content-rst content-rst)))
    (restas:redirect 'post-permalink :id id)))
                                         
;; edit post

(restas:define-route admin-edit-post ("admin/:id")
  (check-admin-rights)
  (list :admin-edit-post-page
        :post (st.get-single-post id)))

(restas:define-route admin-cancel-edit-post ("admin/:id"
                                             :method :post
                                             :requirement (form-action-p "cancel"))
  (declare (ignore id))
  (check-admin-rights)
  (restas:redirect 'admin-entry))

(restas:define-route admin-preview-edit-post ("admin/:id"
                                             :method :post
                                             :requirement (form-action-p "preview"))
  (declare (ignore id))
  (check-admin-rights)
  (preview-post))

(restas:define-route admin-save-edit-post ("admin/:id"
                                           :method :post
                                           :requirement (form-action-p "save"))
  (check-admin-rights)
  (let ((content-rst (hunchentoot:post-parameter "content")))
    (st.update-post id
                    (hunchentoot:post-parameter "title")
                    (post-parameter-tags)
                    (render-arblog-markup content-rst)
                    :content-rst content-rst))
  (restas:redirect 'post-permalink :id id))
