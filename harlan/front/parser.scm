(library
  (harlan front parser)
  (export parse-harlan)
  (import
    (rnrs)
    (util verify-grammar)
    (util helpers)
    (util match))

;; parse-harlan takes a syntax tree that a user might actually want
;; to write and converts it into something that's more easily
;; analyzed by the type inferencer and the rest of the compiler. This
;; subsumes the functionality of the previous simplify-literals
;; mini-pass.
  
(define-match parse-harlan
  ((module ,[parse-decl -> decl*] ...)
   `(module . ,decl*)))

(define-match parse-decl
  ((extern ,name . ,[parse-type -> t])
   (guard (symbol? name))
   `(extern ,name . ,t))
  ((fn ,name ,args ,[parse-stmt -> stmt*] ...)
   `(fn ,name ,args . ,stmt*)))

(define-match parse-type
  (int 'int)
  (u64 'u64)
  (void 'void)
  (str 'str)
  (float 'float)
  ((vector ,[t] ,n)
   (guard (integer? n))
   `(vector ,t ,n))
  (((,[t*] ...) -> ,[t]) `(,t* -> ,t)))

(define-match parse-stmt
  ((assert ,[parse-expr -> e])
   `(assert ,e))
  ((print ,[parse-expr -> e])
   `(print ,e))
  ((return ,[parse-expr -> e])
   `(return ,e))
  ((for (,x ,[parse-expr -> start] ,[parse-expr -> end]) ,[stmt*] ...)
   (guard (symbol? x))
   `(for (,x ,start ,end) . ,stmt*))
  ((while ,[parse-expr -> test] ,[stmt*] ...)
   `(while ,test . ,stmt*))
  ((set! ,[parse-expr -> x] ,[parse-expr -> e])
   `(set! ,x ,e))
  ((vector-set! ,[parse-expr -> v] ,[parse-expr -> i] ,[parse-expr -> e])
   `(vector-set! ,v ,i ,e))
  ((let ,x ,[parse-expr -> e])
   (guard (symbol? x))
   `(let ,x ,e))
  (,[parse-expr -> e] `(do ,e)))

(define-match parse-expr
  (,f (guard (float? f)) `(float ,f))
  (,n (guard (integer? n)) `(num ,n))
  (,str (guard (string? str)) `(str ,str))
  ((var ,x)
   (guard (symbol? x))
   `(var ,x))
  ((vector ,[e*] ...)
   `(vector . ,e*))
  ((make-vector ,[e])
   `(make-vector ,e))
  ((iota ,[e])
   `(iota ,e))
  ((vector-ref ,[v] ,[i])
   `(vector-ref ,v ,i))
  ((length ,[e])
   `(length ,e))
  ((int->float ,[e]) `(int->float ,e))
  ((kernel ((,x ,[e*]) ...) ,[parse-stmt -> stmt*] ... ,[e])
   `(kernel ,(map list x e*) ,@stmt* ,e))
  ((reduce ,op ,[e])
   (guard (reduceop? op))
   `(reduce ,op ,e))
  ((,op ,[lhs] ,[rhs])
   (guard (or (binop? op) (relop? op)))
   `(,op ,lhs ,rhs))
  (,x (guard (symbol? x)) `(var ,x))
  ((,rator ,[rand*] ...)
   (guard (symbol? rator))
   `(call ,rator . ,rand*)))

;; end library
)