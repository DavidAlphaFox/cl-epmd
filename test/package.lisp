(defpackage #:epmd-test
  (:documentation "Unit tests for the EPMD functions.")
  (:use #:cl #:epmd-protocol #:epmd-client #:fiveam #:flexi-streams)
  (:export

   #:run-all-tests

   ))

(in-package :epmd-test)

(def-suite epmd-protocol)
(def-suite epmd-client)
(def-suite epmd-server)

(defun run-all-tests ()
  (run! 'epmd-protocol)
  (run! 'epmd-client)
  (run! 'epmd-server))
