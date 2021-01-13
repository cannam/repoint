
structure StatusCache = struct

    val empty : status_cache = ref []

    fun lookup (lib : libname) (cache : status_cache) : string option =
        let fun lookup' [] = NONE
              | lookup' ({ libname, status } :: rs) =
                if libname = lib
                then SOME status
                else lookup' rs
        in
            lookup' (! cache)
        end

    fun drop (lib : libname) (cache : status_cache) : unit =
        let fun drop' [] = []
              | drop' ((r as { libname, status }) :: rs) =
                if libname = lib
                then rs
                else r :: drop' rs
        in
            cache := drop' (! cache)
        end
            
    fun add (status_rec : status_rec) (cache : status_cache) : unit =
        let val () = drop (#libname status_rec) cache
        in
            cache := status_rec :: (! cache)
        end
end
