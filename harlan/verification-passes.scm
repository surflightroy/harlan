(library
  (harlan verification-passes)
  (export
    verify-harlan
    verify-parse-harlan
    verify-returnify
    verify-lift-vectors
    verify-typecheck
    verify-lower-vectors
    verify-returnify-kernels
    verify-remove-nested-kernels
    verify-uglify-vectors
    verify-annotate-free-vars
    verify-hoist-kernels
    verify-move-gpu-data
    verify-generate-kernel-calls
    verify-compile-module
    verify-convert-types
    verify-compile-kernels)
  (import
    (rnrs)
    (util helpers)
    (util verify-grammar))

  (grammar-transforms

    (%static
      (Type
        scalar-type
        (vector Type Integer)
        (ptr Type)
        ((Type *) -> Type))
      (Var ident)
      (Integer integer)
      (Reduceop reduceop)
      (Binop binop)
      (Relop relop)
      (Float float)
      (String string)
      (Number number))
    
    (harlan
      (Start Module)
      (Module (module Decl +))
      (Decl
        (extern Var (Type *) -> Type)
        (fn Var (Var *) Expr +))
      (Expr
        integer
        float
        string
        ident
        (let Var Expr)
        (print Expr)
        (assert Expr)
        (set! Expr Expr)
        (vector-set! Expr Expr Expr)
        (for (Var Expr Expr) Expr +)
        (while Expr Expr +)
        (return Expr)
        (var Var)
        (vector Expr +)
        (vector-ref Expr Expr)
        (kernel ((Var Expr) +) Expr * Expr)
        (reduce Reduceop Expr)
        (iota Integer)
        (length Expr)
        (make-vector Integer)
        (Binop Expr Expr)
        (Relop Expr Expr)
        (Var Expr *)))

    (parse-harlan (%inherits Module)
      (Start Module)
      (Decl
        (extern Var (Type *) -> Type)
        (fn Var (Var *) Stmt +))
      (Stmt
        (let Var Expr)
        (print Expr)
        (assert Expr)
        (set! Expr Expr)
        (vector-set! Expr Expr Expr)
        (do Expr)
        (for (Var Expr Expr) Stmt +)
        (while Expr Stmt +)
        (return Expr))
      (Expr
        (num Integer)
        (float Float)
        (str String)
        (var Var)
        (vector Expr +)
        (vector-ref Expr Expr)
        (kernel ((Var Expr) +) Stmt * Expr)
        (reduce Reduceop Expr)
        (iota (num Integer))
        (length Expr)
        (int->float Expr)
        (make-vector (num Integer))
        (Binop Expr Expr)
        (Relop Expr Expr)
        (call Var Expr *)))

    (typecheck (%inherits Module)
      (Start Module)
      (Decl
        (extern Var (Type *) -> Type)
        (fn Var (Var *) Type Stmt +))
      (Stmt
        (let Var Type Expr)
        (print Expr)
        (assert Expr)
        (set! Expr Expr)
        (vector-set! Type Expr Expr Expr)
        (do Expr)
        (for ((Var Type) Expr Expr) Stmt +)
        (while Expr Stmt +)
        (return Expr))
      (Expr
        (int Integer)
        (u64 Number)
        (float Float)
        (str String)
        (var Type Var)
        (vector Type Expr +)
        (vector-ref Type Expr Expr)
        (kernel Type (((Var Type) (Expr Type)) +) Stmt * Expr)
        (reduce Type Reduceop Expr)
        (iota (int Integer))
        (length Expr)
        (int->float Expr)
        (make-vector Type (int Integer))
        (Binop Expr Expr)
        (Relop Expr Expr)
        (call Type Var Expr *)))

    (returnify (%inherits Module Expr)
      (Start Module)
      (Decl
        (fn Var (Var *) Type Stmt * Ret-Stmt)
        (extern Var (Type *) -> Type))
      (Stmt
        (let Var Type Expr)
        (print Expr)
        (assert Expr)
        (set! Expr Expr)
        (vector-set! Type Expr Expr Expr)
        (do Expr)
        (for ((Var Type) Expr Expr) Stmt +)
        (while Expr Stmt +)
        Ret-Stmt)
      (Ret-Stmt (return Expr)))

    (lift-vectors (%inherits Module Decl Ret-Stmt)
      (Start Module)
      (Stmt
        (let Var Type Let-Expr)
        (print Expr)
        (assert Expr)
        (set! Expr Expr)
        (vector-set! Type Expr Expr Expr)
        (do Expr +)
        (for ((Var Type) Expr Expr) Stmt +)
        (while Expr Stmt *)
        Ret-Stmt)
      (Let-Expr
        (kernel Type (((Var Type) (Let-Expr Type)) +) Stmt * Let-Expr)
        (vector Let-Expr +)
        (reduce Type Reduceop Let-Expr)
        (make-vector Type (int Integer))
        (iota (int Integer))
        Expr)
      (Expr
        (int Integer)
        (u64 Number)
        (float Float)
        (str String)
        (var Type Var)
        (int->float Expr)
        (length Expr)
        (call Type Var Expr *)
        (vector-ref Type Expr Expr)
        (Binop Expr Expr)
        (Relop Expr Expr)))

    (lower-vectors (%inherits Module Decl Ret-Stmt)
      (Start Module)
      (Stmt 
        (print Expr)
        (assert Expr)
        (set! Expr Expr)
        (vector-set! Type Expr Expr Expr)
        (let Var Type Let-Expr)
        (for (Var Expr Expr) Stmt +)
        (while Expr Stmt +)
        (do Expr +)
        Ret-Stmt)
      (Let-Expr
        (kernel Type (((Var Type) (Expr Type)) +) Stmt * Let-Expr)
        Expr)
      (Expr
        (int Integer)
        (u64 Number)
        (float Float)
        (int->float Expr)
        (str String)
        (var Type Var)
        (call Type Var Expr *)
        (vector-ref Type Expr Expr)
        (length Expr)
        (Relop Expr Expr)
        (Binop Expr Expr)))

    (remove-nested-kernels
      (%inherits Module Decl Ret-Stmt Expr Stmt)
      (Start Module)
      (Let-Expr
        (kernel Type (((Var Type) (Expr Type)) +) Stmt * Expr)
        Expr))

    (returnify-kernels (%inherits Module Decl Ret-Stmt Expr)
      (Start Module)
      (Stmt 
        (print Expr)
        (print Expr Expr)
        (assert Expr)
        (set! (var Type Var) Expr)
        (vector-set! Type Expr Expr Expr)
        (kernel Type (((Var Type) (Expr Type)) +) Stmt +)
        (let Var Type Expr)
        (for (Var Expr Expr) Stmt +)
        (while Expr Stmt +)
        (do Expr +)
        Ret-Stmt))

    (uglify-vectors (%inherits Module Decl Ret-Stmt)
      (Start Module)
      (Stmt 
        (print Expr)
        (assert Expr)
        (set! Expr Expr)
        (kernel (((Var Type) (Expr Type)) +) Stmt +)
        (let Var Type Expr)
        (for (Var Expr Expr) Stmt +)
        (while Expr Stmt +)
        (do Expr +)
        Ret-Stmt)
      (Expr 
        (int Integer)
        (u64 Number)
        (str String)
        (float Float)
        (var Type Var)
        (call Type Var Expr *)
        (cast Type Expr)
        (sizeof Type)
        (addressof Expr)
        (vector-ref Type Expr Expr)
        (length Expr)
        (Relop Expr Expr)
        (Binop Expr Expr)))

    (annotate-free-vars
      (%inherits Module Decl Expr Ret-Stmt)
      (Start Module)
      (Stmt 
        (print Expr)
        (assert Expr)
        (set! Expr Expr)
        (kernel (((Var Type) (Expr Type)) +)
          (free-vars (Var Type) *) Stmt +)
        (let Var Type Expr)
        (for (Var Expr Expr) Stmt +)
        (while Expr Stmt +)
        (do Expr +)
        Ret-Stmt))

    (hoist-kernels (%inherits Module Ret-Stmt)
      (Start Module)
      (Decl
        (gpu-module Kernel *)
        (fn Var (Var *) ((Type *) -> Type) Stmt +)
        (extern Var (Type *) -> Type))
      (Kernel
        (kernel Var ((Var Type) +) Stmt *))
      (Stmt 
        (print Expr)
        (assert Expr)
        (set! Expr Expr)
        (apply-kernel Var (var Type Var) +)
        (let Var Type Expr)
        (for (Var Expr Expr) Stmt +)
        (while Expr Stmt +)
        (do Expr +)
        Ret-Stmt)
      (Expr 
        (int Integer)
        (u64 Number)
        (str String)
        (float Float)
        (var Type Var)
        (deref (var Type Var))
        (call Type Var Expr *)
        (call Type Field Expr *)
        (cast Type Expr)
        (sizeof Type)
        (addressof Expr)
        (vector-ref Type Expr Expr)
        (length Expr)
        (Relop Expr Expr)
        (Binop Expr Expr))
      (Field
        (field (var cl::program g_prog) build)))

    (move-gpu-data
      (%inherits Module Kernel Decl Expr Ret-Stmt Field)
      (Start Module)
      (Stmt 
        (print Expr)
        (assert Expr)
        (set! Expr Expr)
        (apply-kernel Var (var Type Var) +)
        (let-gpu Var Type)
        (map-gpu ((Var Expr)) Stmt)
        (let Var Type Expr)
        (for (Var Expr Expr) Stmt +)
        (while Expr Stmt +)
        (do Expr +)
        Ret-Stmt))

    (generate-kernel-calls
      (%inherits Module Kernel Decl Expr Ret-Stmt)
      (Start Module)
      (Stmt
        (print Expr)
        (assert Expr)
        (set! Expr Expr)
        (let-gpu Var Type)
        (map-gpu ((Var Expr)) Stmt)
        (let Var Type Expr)
        (for (Var Expr Expr) Stmt +)
        (while Expr Stmt +)
        (do Expr +)
        (block Stmt +)
        Ret-Stmt)
      (Field
        (field (var Type Var) Var)))

    (compile-module
      (%inherits Ret-Stmt Kernel)
      (Start Module)
      (Module (Decl *))
      (Decl
        (gpu-module Kernel *)
        (func Type Var (Type *) Stmt +)
        (extern Type Var (Type *)))
      (Stmt
        (print Expr)
        (set! Expr Expr)
        (map-gpu ((Var Expr)) Stmt)
        (let Var Let-Type Expr)
        (for (Var Expr Expr) Stmt +)
        (while Expr Stmt +)
        (do Expr +)
        (block Stmt +)
        Ret-Stmt)
      (Expr 
        integer
        number
        string
        float
        Var
        (deref Var)
        (Var Expr *)
        (Field Expr *)
        (assert Expr)
        (cast Type Expr)
        (memcpy Expr Expr Expr)
        (sizeof Type)
        (addressof Expr)
        (vector-ref Expr Expr)
        (length Expr)
        (Relop Expr Expr)
        (Binop Expr Expr))
      (Field
        (field Var +)
        (field Var + Type))
      (Let-Type
        (cl::buffer Type)
        (cl::buffer_map Type)
        Type))

    (convert-types (%inherits Module Stmt Ret-Stmt)
      (Start Module)
      (Decl
        (gpu-module Kernel *)
        (func C-Type Var (C-Type *) Stmt +)
        (extern C-Type Var (C-Type *))) 
      (Kernel
        (kernel Var ((Var C-Type) +) Stmt *))
      (Expr 
        integer
        number
        string
        float
        Var
        (deref Var)
        (Var Expr *)
        (Field Expr *)
        (assert Expr)
        (cast C-Type Expr)
        (memcpy Expr Expr Expr)
        (sizeof C-Type)
        (addressof Expr)
        (vector-ref Expr Expr)
        (length Expr)
        (Relop Expr Expr)
        (Binop Expr Expr))
      (Field
        (field Var +)
        (field Var + C-Type))
      (Let-Type
        (cl::buffer C-Type)
        (cl::buffer_map C-Type)
        C-Type)
      (C-Type
        (const-ptr C-Type)
        (ptr C-Type)
        c-type))

    (compile-kernels (%inherits Module Stmt Ret-Stmt Expr Field Let-Type C-Type)
      (Start Module)
      (Decl
        (global cl::program g_prog
          ((field g_ctx createProgramFromSource) String))
        (func C-Type Var (C-Type *) Stmt +)
        (extern C-Type Var (C-Type *)))))

)