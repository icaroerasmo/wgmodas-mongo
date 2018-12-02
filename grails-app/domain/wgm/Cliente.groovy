package wgm

class Cliente {

    Long id
    String nome
    String cpf_cnpj
    String endereco
    String telefone

    static constraints = {
        nome blank: false, nullable: false
        cpf_cnpj blank: false, nullable: false, unique: true
        endereco blank: false, nullable: false
        telefone blank: false, nullable: false
    }

    String toString() { "$nome" }
}
