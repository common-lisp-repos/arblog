;;;; defmodule.lisp

(restas:define-module #:arblog
  (:use #:cl #:iter)
  (:export #:*datastore*
           #:*markup*
           #:*theme*

           #:*disqus-enabled*
           #:*disqus-shortname*
           #:*disqus-developer-mode*

           #:*posts-on-page*
           #:*blog-name*

           #:register-theme-static-dir))

(in-package #:arblog)

(defparameter *disqus-enabled* nil)
(defparameter *disqus-shortname* nil)
(defparameter *disqus-developer-mode* t)

(defparameter *posts-on-page* 10)

(defparameter *blog-name* "blog")

(restas:define-policy datastore
  (:interface-package #:arblog.policy.datastore)
  (:interface-method-template "DATASTORE-~A")
  (:internal-function-template "DS.~A")
  
  (define-method count-posts (&optional tag)
    "Return a count of the posts that are published")
  
  (define-method list-recent-posts (skip limit &key tag fields)
    "Retrieve the recent posts.")
  
  (define-method find-single-post (year month day title)
    "Retrieve a single post, based on date and post title")

  (define-method get-single-post (id &key fields)
    "Retrieve a single post, based  on post ID")

  (define-method list-archive-posts (min max &optional fields)
    "Retrieve archive posts")

  (define-method all-tags ()
    "Retrieve an array of tags")

  (define-method insert-post (title tags content &key markup published updated)
    "Insert post in the datastore and return the post ID of the created post")

  (define-method update-post (id title tags content &key markup)
    "Update post in the datastore")

  (define-method set-admin (name password)
    "Set administrator name and password")

  (define-method check-admin (name password)
    "Check for administrator rights"))

(restas:define-policy markup
  (:interface-package #:arblog.policy.markup)
  (:interface-method-template "MARKUP-~A")
  (:internal-function-template "MARKUP.~A")

  (define-method render-content (content)
    "Generate HTML from markup"))

(restas:define-policy theme
  (:interface-package #:arblog.policy.theme)
  (:interface-method-template "THEME-~A")
  (:internal-function-template "RENDER.~A")

  (define-method list-recent-posts (posts navigation))
  
  (define-method archive-for-year (year months))
  (define-method archive-for-month (year month posts))
  (define-method archive-for-day (year month day posts))
  (define-method one-post (post))

  (define-method all-tags (tags))
  (define-method posts-with-tag (tag posts navigation))

  (define-method admin-posts (posts navigation))
  (define-method admin-edit-post (&key title markup tags preview)))


(defparameter *theme-static-dir-map* (make-hash-table :test 'equal))

(defun register-theme-static-dir (theme-name path)
  (setf (gethash theme-name *theme-static-dir-map*)
        path))
