package wgm

class Vendedora {

    Long id
    String nome
	String cpf
    String endereco
	String telefone

    Usuario usuario
    Distribuidora distribuidora

    static constraints = {
        nome blank: false, nullable: false
        cpf blank: false, nullable: false, unique: true
        endereco blank: false, nullable: false
        telefone blank: false, nullable: false
    }

    static mapping = {
        usuario cascade: 'all-delete-orphan'
    }

    String toString() { "$nome" }
}
