package wgm

class Usuario {

    Long id
	String email
	String senha
    
    static mapping = {
        version false
    }

    static constraints = {
        email blank: false, nullable: false
        senha blank: false, nullable: false
    }

    String toString() { "$email" }
}
