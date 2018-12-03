package wgm

class Cliente {

    Long id
    String nome
    String cpfCnpj
    String endereco
    String telefone

    static mapping = {
        version false
    }

    static constraints = {
        nome blank: false, nullable: false
        cpfCnpj blank: false, nullable: false, unique: true
        endereco blank: false, nullable: false
        telefone blank: false, nullable: false
    }

    String toString() { "$nome" }
}
