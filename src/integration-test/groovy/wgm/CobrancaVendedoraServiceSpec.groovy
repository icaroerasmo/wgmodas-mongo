package wgm

import grails.testing.mixin.integration.Integration
import grails.gorm.transactions.Rollback
import spock.lang.Specification
import org.hibernate.SessionFactory

@Integration
@Rollback
class CobrancaVendedoraServiceSpec extends Specification {

    CobrancaVendedoraService cobrancaVendedoraService
    SessionFactory sessionFactory

    private Long setupData() {
        // TODO: Populate valid domain instances and return a valid ID
        //new CobrancaVendedora(...).save(flush: true, failOnError: true)
        //new CobrancaVendedora(...).save(flush: true, failOnError: true)
        //CobrancaVendedora cobrancaVendedora = new CobrancaVendedora(...).save(flush: true, failOnError: true)
        //new CobrancaVendedora(...).save(flush: true, failOnError: true)
        //new CobrancaVendedora(...).save(flush: true, failOnError: true)
        assert false, "TODO: Provide a setupData() implementation for this generated test suite"
        //cobrancaVendedora.id
    }

    void "test get"() {
        setupData()

        expect:
        cobrancaVendedoraService.get(1) != null
    }

    void "test list"() {
        setupData()

        when:
        List<CobrancaVendedora> cobrancaVendedoraList = cobrancaVendedoraService.list(max: 2, offset: 2)

        then:
        cobrancaVendedoraList.size() == 2
        assert false, "TODO: Verify the correct instances are returned"
    }

    void "test count"() {
        setupData()

        expect:
        cobrancaVendedoraService.count() == 5
    }

    void "test delete"() {
        Long cobrancaVendedoraId = setupData()

        expect:
        cobrancaVendedoraService.count() == 5

        when:
        cobrancaVendedoraService.delete(cobrancaVendedoraId)
        sessionFactory.currentSession.flush()

        then:
        cobrancaVendedoraService.count() == 4
    }

    void "test save"() {
        when:
        assert false, "TODO: Provide a valid instance to save"
        CobrancaVendedora cobrancaVendedora = new CobrancaVendedora()
        cobrancaVendedoraService.save(cobrancaVendedora)

        then:
        cobrancaVendedora.id != null
    }
}
