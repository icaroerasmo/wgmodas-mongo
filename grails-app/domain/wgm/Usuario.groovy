package wgm

class Usuario {

    Long id
	String email
	String senha
	String endereco
	String telefone
    
    static constraints = {
        email blank: false, nullable: false
        senha blank: false, nullable: false
        endereco blank: false, nullable: false
        telefone blank: false, nullable: false
    }
}
