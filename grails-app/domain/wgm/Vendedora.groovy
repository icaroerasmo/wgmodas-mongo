package wgm

class Vendedora {

    Long id
    String nome
	String cpf

    Usuario usuario
    Distribuidora distribuidora

    static constraints = {
        nome blank: false, nullable: false
        cpf blank: false, nullable: false, unique: true
    }
}
