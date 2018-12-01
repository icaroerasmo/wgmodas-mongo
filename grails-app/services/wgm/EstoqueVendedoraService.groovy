package wgm

import grails.gorm.services.Service

@Service(EstoqueVendedora)
interface EstoqueVendedoraService {

    EstoqueVendedora get(Serializable id)

    List<EstoqueVendedora> list(Map args)

    Long count()

    void delete(Serializable id)

    EstoqueVendedora save(EstoqueVendedora estoqueVendedora)

}