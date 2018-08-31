module Make (D : sig
  val digest_size : int
end) =
struct
  let eq a b = Eqaf.C.equal a b

  let neq a b = not (eq a b)

  let unsafe_compare a b = String.compare a b
end
