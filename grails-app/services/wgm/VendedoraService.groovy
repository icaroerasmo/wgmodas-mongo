package wgm

import grails.gorm.services.Service

@Service(Vendedora)
interface VendedoraService {

    Vendedora get(Serializable id)

    List<Vendedora> list(Map args)

    Long count()

    void delete(Serializable id)

    Vendedora save(Vendedora vendedora)

}