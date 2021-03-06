;;;; The EPMD protocol

(in-package :epmd-protocol)

(defconstant +node-type-hidden+ 72)
(defconstant +node-type-erlang+ 77)

(defconstant +node-protocol-tcpip4+ 0)


(defun response-class-tag (class)
  (ecase class
    (alive2-response 121)
    (port2-response 119)))

(defun request-class-tag (class)
  (ecase class
    (alive2-request       120)
    (port-please2-request 122)
    (names-request        110)
    (dump-request         100)
    (kill-request         107)
    (stop-request         115)))

(defun find-request-class (tag)
  (ecase tag
    (120 'alive2-request)
    (122 'port-please2-request)
    (110 'names-request)
    (100 'dump-request)
    (107 'kill-request)
    (115 'stop-request)))

(define-tagged-binary-class epmd-request ()
  ((size u2)
   (tag  u1))
  (:dispatch (find-request-class tag)))

(defun read-request (stream)
  (read-value 'epmd-request stream))

(defun write-message (stream message)
  (write-value (type-of message) stream message))


;;;
;;; ALIVE2_REQ
;;
;; 2 bytes: Total length of following message in bytes
;; 1 byte:  'x'               [ALIVE2_REQ message]
;; 2 bytes: Listening port
;; 1 byte:  72                [hidden node (not Erlang node)]
;; 1 byte:  0                 [protocol: tcp/ip v4]
;; 2 bytes: 5                 [highest version supported]
;; 2 bytes: 5                 [lowest version supported]
;; 2 bytes: Length of node name
;; N bytes: Node name
;; 2 bytes: Length of the Extra field
;; M bytes: Extra             [???]
;;

(define-binary-class alive2-request (epmd-request)
  ((port            u2)
   (node-type       u1)
   (protocol        u1)
   (highest-version u2)
   (lowest-version  u2)
   (name-length     u2)
   (name            (iso-8859-1-string :length name-length))
   (extra-length    u2)
   (extra           (iso-8859-1-string :length extra-length))))

(defun make-alive2-request (node-name node-port &key
                            (node-type +node-type-hidden+)
                            (protocol +node-protocol-tcpip4+)
                            (highest-version 5)
                            (lowest-version 5)
                            (extra ""))
  (let* ((node-name-length (length node-name))
         (extra-length (length extra))
         (message-length (+ 13 node-name-length extra-length)))
    (make-instance 'alive2-request
                   :size message-length
                   :tag (request-class-tag 'alive2-request)
                   :port node-port
                   :node-type node-type
                   :protocol protocol
                   :highest-version highest-version
                   :lowest-version lowest-version
                   :name-length node-name-length
                   :name node-name
                   :extra-length extra-length
                   :extra extra)))


;;;
;;; ALIVE2_RESP
;;
;; 1 byte:  'y'               [ALIVE2_RESP message]
;; 1 byte:  Result            [0 means OK, >0 means ERROR]
;; 2 bytes: Creation          [?]
;;

(define-binary-class alive2-response ()
  ((tag      u1)
   (result   u1)
   (creation u2)))

(defun read-alive2-response (stream)
  (read-value 'alive2-response stream))

(defun make-alive2-response (result &optional (creation 0))
  (make-instance 'alive2-response
                 :tag (response-class-tag 'alive2-response)
                 :result result
                 :creation creation))


;;;
;;; PORT_PLEASE2_REQ
;;
;; 2 bytes: Total length of following message
;; 1 byte:  'z'            [PORT_PLEASE2_REQ message]
;; N bytes: Node name
;;

(define-binary-class port-please2-request (epmd-request)
  ((node-name (iso-8859-1-string :length (1- size)))))

(defun make-port-please2-request (node-name)
  (let ((message-length (1+ (length node-name))))
    (make-instance 'port-please2-request
                   :size message-length
                   :tag (request-class-tag 'port-please2-request)
                   :node-name node-name)))


;;;
;;; PORT2_RESP
;;
;; 1 byte:  'w'            [PORT2_RESP message]
;; 1 byte:  Result         [0 means OK, >0 means ERROR]
;;; Continued only if result = 0
;; 2 bytes: Port
;; 1 byte:  Node type      [77 means Erlang node, 72 means hidden node]
;; 1 byte:  Protocol       [0 means TCP/IP v4]
;; 2 bytes: Highest version supported
;; 2 bytes: Lowest version supported
;; 2 bytes: Node name length
;; N bytes: Node name
;; 2 bytes: Extra field length
;; M bytes: Extra field
;;

(define-tagged-binary-class port2-response ()
  ((tag    u1)
   (result u1))
  (:dispatch (if (= 0 result)
                 'port2-node-info-response
                 'port2-null-response)))

(define-binary-class port2-node-info-response (port2-response)
  ((port            u2)
   (node-type       u1)
   (protocol        u1)
   (highest-version u2)
   (lowest-version  u2)
   (name-length     u2)
   (name            (iso-8859-1-string :length name-length))
   (extra-length    u2)
   (extra           (iso-8859-1-string :length extra-length))))

(define-binary-class port2-null-response (port2-response)
  ())

(defun read-port2-response (stream)
  (read-value 'port2-response stream))

(defun make-port2-null-response (&optional (result 1))
  (make-instance 'port2-null-response
                 :tag (response-class-tag 'port2-response)
                 :result result))

(defun make-port2-node-info-response (node-name node-port &key
                                      (node-type +node-type-erlang+)
                                      (protocol +node-protocol-tcpip4+)
                                      (highest-version 5)
                                      (lowest-version 5)
                                      (extra ""))
  (let ((node-name-length (length node-name))
        (extra-length (length extra)))
    (make-instance 'port2-node-info-response
                   :tag (response-class-tag 'port2-response)
                   :result 0
                   :port node-port
                   :node-type node-type
                   :protocol protocol
                   :highest-version highest-version
                   :lowest-version lowest-version
                   :name-length node-name-length
                   :name node-name
                   :extra-length extra-length
                   :extra extra)))


;;;
;;; NAMES_REQ
;;
;; 2 bytes: Total length of following message
;; 1 byte:  'n'            [NAMES_REQ message]
;;

(define-binary-class names-request (epmd-request)
  ())

(defun make-names-request ()
  (make-instance 'names-request
                 :size 1
                 :tag (request-class-tag 'names-request)))


;;;
;;; NAMES_RESP
;;
;; 4 bytes: EPMDPortNo     Why do we get this?
;; N bytes: NodeInfo
;;

(define-binary-type iso-8859-1-string-until-eof ()
  (:reader (in)
    (coerce (loop for b = (read-byte in nil) while b collect (code-char b))
            'string))
  (:writer (out string)
    (loop for c across string do (write-byte (char-code c) out))
    (close out)))

(define-binary-class names-response ()
  ((epmd-port-number u4)
   (node-info        iso-8859-1-string-until-eof)))

(defun read-names-response (stream)
  (read-value 'names-response stream))

(defun make-names-response (port node-info)
  (make-instance 'names-response
                 :epmd-port-number port
                 :node-info node-info))


;;;
;;; DUMP_REQ
;;
;; 2 bytes: Total length of following message in bytes
;; 1 byte:  'd'            [DUMP_REQ message]
;;

(define-binary-class dump-request (epmd-request)
  ())

(defun make-dump-request ()
  (make-instance 'dump-request
                 :size 1
                 :tag (request-class-tag 'dump-request)))


;;;
;;; DUMP_RESP
;;
;; 4 bytes: EPMDPortNo
;; N bytes: NodeInfo
;;

(define-binary-class dump-response ()
  ((epmd-port-number u4)
   (node-info        iso-8859-1-string-until-eof)))

(defun read-dump-response (stream)
  (read-value 'dump-response stream))

(defun make-dump-response (port node-info)
  (make-instance 'dump-response
                 :epmd-port-number port
                 :node-info node-info))


;;;
;;; KILL_REQ
;;
;; 2 bytes: Total length of following message in bytes
;; 1 byte:  'k'            [KILL_REQ message]
;;

(define-binary-class kill-request (epmd-request)
  ())

(defun make-kill-request ()
  (make-instance 'kill-request
                 :size 1
                 :tag (request-class-tag 'kill-request)))


;;;
;;; KILL_RESP
;;
;; 2 bytes: OKString
;;

(define-binary-class kill-response ()
  ((ok-string (iso-8859-1-string :length 2))))

(defun read-kill-response (stream)
  (read-value 'kill-response stream))

(defun make-kill-response ()
  (make-instance 'kill-response :ok-string "OK"))


;;;
;;; STOP_REQ
;;
;; 2 bytes: Total length of following message in bytes
;; 1 byte:  's'            [STOP_REQ message]
;; n bytes: NodeName
;;

(define-binary-class stop-request (epmd-request)
  ((node-name (iso-8859-1-string :length (1- size)))))

(defun make-stop-request (node-name)
  (make-instance 'stop-request
                 :size (length node-name)
                 :tag (request-class-tag 'stop-request)
                 :node-name node-name))


;;;
;;; STOP_RESP / STOP_NOTOK_RESP
;;
;; 7 bytes: OKString / NOKString
;;

(define-tagged-binary-class stop-response ()
  ((ok-string (iso-8859-1-string :length 7)))
  (:dispatch (cond
               ((string= ok-string "STOPPED") 'stop-ok-response)
               ((string= ok-string "NOEXIST") 'stop-not-ok-response))))

(define-binary-class stop-ok-response (stop-response)
  ())

(define-binary-class stop-not-ok-response (stop-response)
  ())

(defun read-stop-response (stream)
  (read-value 'stop-response stream))

(defun make-stop-ok-response ()
  (make-instance 'stop-ok-response :ok-string "STOPPED"))

(defun make-stop-not-ok-response ()
  (make-instance 'stop-not-ok-response :ok-string "NOEXIST"))
